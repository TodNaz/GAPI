module app;

import gapi;
import gapi.extensions.sdlsurface;
import gapi.extensions.utilmessenger;
import gapi.extensions.backendnative;

import bindbc.sdl;
import imagefmt;
import std.file : read;
import std.stdio : writeln;

int main(string[] args)
{
    Instance instance;
    createInstance(
        CreateInstanceInfo(
            ApplicationInfo(
                "01 - Device creation",
                0x01,
                "GAPI",
                0x00
            ),
            ["GAPISDLWindowInfo"]
        ),
        theAllocator(),
        instance
    );

    writeln ("04 - Texture1D");

    writeln ("Find best device...");
    PhysDevice[] pdevices = instance.enumeratePhysicalDevices();
    Device bestDevice;

    size_t maxID, maxScore;

    foreach (i; 0 .. pdevices.length)
    {
        size_t score;
        auto e = pdevices[i];

        PhysDeviceProperties props = e.getProperties();
        score += props.features.geometryShader ? 1000 : 0;
        score += props.features.spirv ? 1000 : 0;
        score += props.features.scissor ? 1000 : 0;
        score += props.limits.maxTextureSize;
        score += props.limits.maxFramebufferLayers * 10;

        if (score > maxScore)
        {
            maxID = i;
            maxScore = score;
        }
    }

    writeln("Best device has find: ", pdevices[maxID].getProperties().deviceName);
    writeln("Create handle device...");

    QueueFamilyProperties[] vq = pdevices[maxID].getQueueFamilyProperties();
    QueueCreateInfo[] cq = new QueueCreateInfo[](vq.length);
    size_t graphID;
    size_t presentID;

    foreach (i; 0 .. vq.length)
    {
        if ((vq[i].queueFlags & QueueFlag.graphicsBit))
        {
            graphID = i;
        }

        if ((vq[i].queueFlags & QueueFlag.presentBit))
        {
            presentID = i;
        }

        cq[i] = QueueCreateInfo(
            cast(uint) i, vq[i].queueCount, 1.0f
        );
    }

    bestDevice = instance.createDevice(
        pdevices[maxID], DeviceCreateInfo(
            cq,
            [
                ValidationLayerInfo(
                    "GAPIDebugUtilMessenger",
                    true,
                    LoggingDeviceInfo(
                        true, Logger(
                            null, 
                            (LogLevel level, string message, string file, string func, int line, void[] data)
                            {
                                writeln ("[", level, "] ", file, ":", func, ":", line, " -> ", message);
                            }
                        ),
                        LoggingLayer(true, true, true)
                    )
                ),
                ValidationLayerInfo(
                    "GPUNativeBackendUtilMessenger",
                    true,
                    NativeLoggingInfo(
                        true, Logger(
                            null, 
                            (LogLevel level, string message, string file, string func, int line, void[] data)
                            {
                                writeln ("[", level, "] ", file, ":", func, ":", line, " -> ", message);
                            }
                        )
                    )
                )
            ]
        )
    );

    writeln("Device handle has created!");
    writeln("Create SDL window...");

    loadSDL();
    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS);
    SDL_Window* window = SDL_CreateWindow(
        "Test", 0, 0, 640, 480, 0
    );

    writeln("Create surface for window...");

    Surface surface = createSurfaceFromWindow(
        instance, SDL_WindowInfo(
            &window
        )
    );

    writeln("Create swapchain...");

    SwapChain swapChain = surface.createSwapChain(
        bestDevice, CreateSwapChainInfo(
            Format(8, 8, 8, 8, 24, 8, 4),
            PresentMode.fifo,
            [640, 480]
        )
    );

    IFImage image = read_image("texture.jpg", 4);
    scope(exit) image.free();

    writeln("SwapChain has created!");

    Queue[] queues = bestDevice.getQueues();
    Queue graphQueue = queues[graphID];
    Queue presentQueue = queues[presentID];
    
    CommandPool pool;
    pool.cmdFlag = QueueFlag.graphicsBit;

    FrameBuffer frame;
    Buffer frameBuffer;

    Buffer vertexBuffer;
    Image gimage;
    Sampler sampler;

    ShaderModule vertex, fragment;
    CompileStatus vertexStatus, fragmentStatus;
    Pipeline pipeline;

    pool.commands = [
        Command(CommandType.createFrameBuffer, CmdCreateFrameBuffer(
            &frame
        )),
        Command(CommandType.createBuffer, CmdCreateBuffer(
            &frameBuffer, BufferUsage.renderbuffer
        )),
        Command(CommandType.createShaderModule, CmdCreateShaderModule(
            &vertex, CodeType.spirv, StageType.vertex, read("shader.vert.spirv"), &vertexStatus
        )),
        Command(CommandType.createShaderModule, CmdCreateShaderModule(
            &fragment, CodeType.spirv, StageType.fragment, read("shader.frag.spirv"), &fragmentStatus
        )),
        Command(CommandType.createBuffer, CmdCreateBuffer(
            &vertexBuffer, BufferUsage.array
        )),
        Command(CommandType.createImage, CmdCreateImage(
            ImageType.image2D, image.w, image.h, 1, InternalFormat.rgba8, &gimage
        ))
    ];

    graphQueue.handle(pool);

    if (vertexStatus.errorid)
    {
        throw new Exception(vertexStatus.log);
    }

    if (fragmentStatus.errorid)
    {
        throw new Exception(fragmentStatus.log);
    }

    float[] vertexes = [
        -0.5f, -0.5f, 0.0f, 0.0f,
        0.5f, -0.5f, 1.0f, 0.0f,
        0.0f,  0.5f, 0.0f, 1.0f
    ];

    pool.commands = [
        Command(CommandType.createSampler, CmdCreateSampler(
            gimage, &sampler, FilterType.nearest, FilterType.nearest,
            SamplerAddressMode.repeat, SamplerAddressMode.repeat, SamplerAddressMode.repeat
        )),
        Command(CommandType.bindImageMemory, CmdBindImageMemory(
            gimage, image.buf8, 0, image.buf8.length
        )),
        Command(CommandType.allocRenderBuffer, CmdAllocRenderBuffer(
            frameBuffer, 640, 480
        )),
        Command(CommandType.frameBufferBindBuffer, CmdFrameBufferBindBuffer(
            frame, frameBuffer
        )),
        Command(CommandType.allocBuffer, CmdAllocBuffer(
            vertexBuffer, vertexes.length * float.sizeof
        )),
        Command(CommandType.bufferSetData, CmdBuffSetData(
            vertexBuffer, 0, float.sizeof * vertexes.length, vertexes
        ))
    ];

    graphQueue.handle(pool);

    pool.commands = [
        Command(CommandType.createPipeline, CmdCreatePipeline(
            &pipeline, [
                ShaderStage(
                    vertex, StageType.vertex, "main"
                ),
                ShaderStage(
                    fragment, StageType.fragment, "main"
                )
            ],
            ViewportState(
                Viewport(0, 0, 640, 480, 0.0, 1.0),
                Scissor([0, 0], [640, 480])
            ),
            RasterizationState(false, true, PolygonMode.fill, 1.0f),
            ColorBlendAttachmentState(true, 
                BlendFactor.SrcAlpha, BlendFactor.OneMinusSrcAlpha, BlendOp.add,
                BlendFactor.One, BlendFactor.Zero, BlendOp.add, [0.0f, 0.0f, 0.0f, 0.0f]
            ),
            VertexInputBindingDescription(
                0, 4 * float.sizeof,
                [
                    VertexInputAttributeDescription(
                        0, VertexAttributeFormat.Float, 2, 0
                    ),
                    VertexInputAttributeDescription(
                        1, VertexAttributeFormat.Float, 2, 2 * float.sizeof
                    )
                ]
            ),
            AttachmentDescription(true, 4),
            [
                WriteDescription(
                    WriteDescriptType.imageSampler,
                    0,
                    ImageViewDescript(
                        gimage, sampler
                    )
                )
            ],
            null
        ))
    ];

    graphQueue.handle(pool);

    SDL_Event event;

    bool hasRun = true;
    while (hasRun)
    {
        while (SDL_PollEvent(&event))
        {
            if (event.type == SDL_EventType.SDL_QUIT)
            {
                hasRun = false;
            }
        }

        pool.commands = [
            Command(CommandType.renderPassBegin, CmdRenderPassInfo(
                frame, RenderArea([0, 0], [640, 480]),
                [1.0f, 0.0f, 0.0f, 1.0f]
            )),
            Command(CommandType.draw, CmdDraw(
                pipeline, vertexBuffer, null, 3, PrimitiveTopology.triangles
            )),
            Command(CommandType.renderPassEnd),
            Command(CommandType.blitFrameBufferToSurface, CmdBlitFrameBufferToSurface(
                frame, 0, 0, 640, 480
            ))
        ];

        graphQueue.submit(pool);
        presentQueue.submit(CommandPool(
            QueueFlag.presentBit, [
                Command(CommandType.present, CmdPresentInfo(
                    swapChain, 0, 0, 640, 480
                ))
            ]
        ));
        bestDevice.handleQueues();
    }

    SDL_DestroyWindow(window);
    SDL_Quit();

    unloadSDL();

    return 0;
}