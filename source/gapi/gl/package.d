module gapi.gl;

import gapi; //

version(BackendGL):

mixin template implErrState(alias message, alias e)
{
    debug
    {
        ErrorState state = ErrorState(
            e.file, 
            e.line, 
            message,
            cast(immutable) e
        );
    } else
    {
        ErrorState state = ErrorState(
            __FILE__,
            __LINE__,
            message,
            cast(immutable) e
        );
    }
}

version (Posix)
{
    import dglx.glx;
    import x11.X;
    import x11.Xlib;
    import x11.Xutil;
}

version (Windows)
{
    import core.sys.windows.windows;
    import wgl.wgl;
}

import nvml.nvml;
import bindbc.opengl;
import gapi.exception;
import std.experimental.allocator;

static this()
{
    createInstance = &glCreateInstance;
    enumerateExtensions  = &glEnumerateExtensions;
}

string[] glEnumerateExtensions(
    RCIAllocator allocator
)
{
    return null;
}

string[] cstrlist(const(char*) cstr) pure @trusted
{
    import std.conv : to;
    import std.array : split;

    return to!(string)(cstr).split(' ');
}

final class GLQueue : Queue
{
    public
    {
        RCIAllocator allocator;
        GLDevice device;
        QueueFlag flag;

        CommandPool[] pl;
        bool hasExecute = false;

        void submit(shared CommandPool pool) shared
        {
            pl ~= pool;
            hasExecute = false;
        }

        void handle(shared CommandPool pool) shared
        {
            import core.atomic;

            pl ~= pool;
            hasExecute = false;

            synchronized
            {
                GLDevice dev = cast(GLDevice) atomicLoad(device);
                dev.handleQueues_modern(this);
            }
        }

        void wait() shared
        {
            while(!hasExecute)
            {

            }
        }

        void submit(CommandPool pool)
        {
            pl ~= pool;
            hasExecute = false;
        }

        void handle(CommandPool pool)
        {
            pl ~= pool;
            hasExecute = false;
            device.handleQueues();
            wait();
        }

        void wait()
        {
            while(!hasExecute)
            {

            }
        }
    }
}

final class GLFrameBuffer : FrameBuffer
{
    public
    {
        uint id;

        this()
        {
            glCreateFramebuffers(1, &id);
        }

        ~this()
        {
            glDeleteFramebuffers(1, &id);
        }
    }
}

enum BufferMode : int
{
    opengl
}

final class GLBuffer : Buffer
{
    public
    {
        uint id;
        BufferUsage type;
        bool hasMap = false;
        size_t _length;
        BufferMode mode;

        void glCreate(BufferUsage type)
        {
            if (type == BufferUsage.renderbuffer)
            {
                glCreateRenderbuffers(1, &id);
            } else
            {
                glCreateBuffers(1, &id);
            }

            this.type = type;
        }

        this(BufferUsage type)
        {
            glCreate(type);
        }

        void alloc(size_t size)
        {
            glNamedBufferData(id, cast(GLsizeiptr) size, null, GL_STATIC_DRAW);
            this._length = size;
        }

        override immutable(size_t) length() @safe
        {
            return this._length;
        } 
    }
}

uint glStage(StageType type)
{
    switch (type)
    {
        case StageType.vertex:
            return GL_VERTEX_SHADER;

        case StageType.fragment:
            return GL_FRAGMENT_SHADER;

        case StageType.geometry:
            return GL_GEOMETRY_SHADER;

        default:
            return 0;
    }
}

final class GLShaderModule : ShaderModule
{
    public
    {
        uint id;
        uint pid;
        StageType _stage;

        this(inout CodeType type, inout StageType stage, shared void[] code, shared CompileStatus* status, RCIAllocator allocator)
        {
            this._stage = stage;

            if (type == CodeType.native)
            {
                pid = glCreateProgram();
                int num;
                int[] formats;
                glGetIntegerv(GL_NUM_PROGRAM_BINARY_FORMATS, &num);
                formats = makeArray!(int)(allocator, num);
                glGetIntegerv(GL_PROGRAM_BINARY_FORMATS, formats.ptr);

                glProgramBinary(pid, formats[0], cast(void*) code.ptr, cast(int) code.length);
            } else
            if (type == CodeType.spirv)
            {
                import std.string : toStringz;

                id = glCreateShader(glStage(stage));

                glShaderBinary(1, &id, GL_SHADER_BINARY_FORMAT_SPIR_V, cast(void*) code.ptr, cast(GLsizei) code.length);
                glSpecializeShaderARB(id, "main", 0, null, null);

                int result;
                glGetShaderiv(id, GL_COMPILE_STATUS, &result);
                if (!result)
                {
                    if (status is null)
                        return;

                    int lenLog;
                    glGetShaderiv(id, GL_INFO_LOG_LENGTH, &lenLog);
                    status.log.length = lenLog;
                    glGetShaderInfoLog(id, lenLog, null, cast(char*) status.log.ptr);
                    status.errorid = result;
                    return;
                }

                pid = glCreateProgram();
                glProgramParameteri(pid, GL_PROGRAM_SEPARABLE, GL_TRUE);
                glAttachShader(pid, id);
                glLinkProgram(pid);
            }
        }

        this(inout StageType stage, inout string code, shared CompileStatus* status)
        {
            this._stage = stage;
            id = glCreateShader(glStage(stage));

            int len = cast(int) code.length;
            glShaderSource(id, 1, [code.ptr].ptr, &len);
            glCompileShader(id);

            int result;
            glGetShaderiv(id, GL_COMPILE_STATUS, &result);
            if (!result)
            {
                if (status is null)
                        return;

                int lenLog;
                glGetShaderiv(id, GL_INFO_LOG_LENGTH, &lenLog);
                status.log.length = lenLog;
                glGetShaderInfoLog(id, lenLog, null, cast(char*) status.log.ptr);
                status.errorid = result;
                return;
            }

            pid = glCreateProgram();
            glProgramParameteri(pid, GL_PROGRAM_SEPARABLE, GL_TRUE);
            glAttachShader(pid, id);
            glLinkProgram(pid);

            glGetProgramiv(pid, GL_LINK_STATUS, &result);
            if (!result)
            {
                if (status is null)
                    return;

                int lenLog;
                glGetProgramiv(pid, GL_INFO_LOG_LENGTH, &lenLog);
                status.log.length = lenLog;
                glGetProgramInfoLog(pid, lenLog, null, cast(char*) status.log.ptr);
                status.errorid = result;
                return;
            }
        }

        StageType stage()
        {
            return _stage;
        }

        ~this() nothrow
        {
            if (id != 0)
                glDeleteShader(id);
        }
    }
}

uint glStagePip(StageType stage)
{
    switch (stage)
    {
        case StageType.vertex:
            return GL_VERTEX_SHADER_BIT;

        case StageType.fragment:
            return GL_FRAGMENT_SHADER_BIT;

        case StageType.geometry:
            return GL_GEOMETRY_SHADER_BIT;

        default:
            return 0;
    }
}

struct PStage
{
    public
    {
        uint pid;
    }
}

final class GLPipeline : Pipeline
{
    public
    {
        CmdCreatePipeline pipelineInfo;
        uint id;
        uint vinfo;

        PStage[] stages;

        this(shared CmdCreatePipeline createPipeline, RCIAllocator allocator)
        {
            this.pipelineInfo = cast(CmdCreatePipeline) createPipeline;
            glCreateProgramPipelines(1, &id);

            stages = makeArray!(PStage)(allocator, pipelineInfo.stages.length);

            size_t i = 0;
            foreach (e; pipelineInfo.stages)
            {
                import std.string : toStringz;

                glUseProgramStages(id, glStagePip(e.stage), (cast(GLShaderModule) e.shaderModule).pid);
                stages[i] = PStage((cast(GLShaderModule) e.shaderModule).pid);
                i++;
            }

            glCreateVertexArrays(1, &vinfo);

            uint glFormat(VertexAttributeFormat attFormat)
            {
                switch (attFormat)
                {
                    case VertexAttributeFormat.Byte:
                        return GL_BYTE;

                    case VertexAttributeFormat.UnsignedByte:
                        return GL_UNSIGNED_BYTE;

                    case VertexAttributeFormat.Short:
                        return GL_SHORT;

                    case VertexAttributeFormat.UnsignedShort:
                        return GL_UNSIGNED_SHORT;

                    case VertexAttributeFormat.Int:
                        return GL_INT;

                    case VertexAttributeFormat.UnsignedInt:
                        return GL_UNSIGNED_INT;

                    case VertexAttributeFormat.Float:
                        return GL_FLOAT;

                    case VertexAttributeFormat.Double:
                        return GL_DOUBLE;

                    default:
                        return 0;
                }
            }

            foreach (VertexInputAttributeDescription e; createPipeline.vertexInput.attributes)
            {
                immutable typeID = glFormat(e.format);

                glEnableVertexArrayAttrib(vinfo, e.location);
                glVertexArrayAttribFormat(vinfo, e.location, e.components, typeID, false, e.offset);
                glVertexArrayAttribBinding(vinfo, e.location, 0);
            }
        }

        ~this()
        {
            glDeleteVertexArrays(1, &vinfo);
            glDeleteProgramPipelines(1, &id);

            foreach (e; stages)
            {
                glDeleteProgram(e.pid);
            }
        }
    }
}

int glInternalFormat(InternalFormat format)
{
    switch (format)
    {
        case InternalFormat.r8:
            return GL_R8;

        case InternalFormat.r16:
            return GL_R16;

        case InternalFormat.rg8:
            return GL_RG8;

        case InternalFormat.rg16:
            return GL_RG16;

        case InternalFormat.rgb4:
            return GL_RGB4;

        case InternalFormat.rgb5:
            return GL_RGB5;

        case InternalFormat.rgb8:
            return GL_RGB8;

        case InternalFormat.rgb10:
            return GL_RGB10;

        case InternalFormat.rgb12:
            return GL_RGB12;

        case InternalFormat.rgb16:
            return GL_RGB16;

        case InternalFormat.rgba2:
            return GL_RGBA2;

        case InternalFormat.rgba4:
            return GL_RGBA4;

        case InternalFormat.rgba8:
            return GL_RGBA8;

        case InternalFormat.rgba12:
            return GL_RGBA12;

        case InternalFormat.rgba16:
            return GL_RGBA16;

        case InternalFormat.r16f:
            return GL_R16F;

        case InternalFormat.rg16f:
            return GL_RG16F;

        case InternalFormat.rgb16f:
            return GL_RGB16F;

        case InternalFormat.rgba16f:
            return GL_RGBA16F;

        case InternalFormat.r32f:
            return GL_R32F;

        case InternalFormat.rg32f:
            return GL_RG32F;

        case InternalFormat.rgb32f:
            return GL_RGB32F;

        case InternalFormat.rgba32f:
            return GL_RGBA32F;

        default:
            return 0;
    }
}

uint glTexType(ImageType type)
{
    final switch(type)
    {
        case ImageType.image1D:
            return GL_TEXTURE_1D;

        case ImageType.image2D:
            return GL_TEXTURE_2D;

        case ImageType.image3D:
            return GL_TEXTURE_3D;
    }
}

final class GLImageView : ImageView
{
    uint id;
    GLImage source;

    this(shared CmdCreateImageView imgVw)
    {
        source = cast(GLImage) imgVw.viewInfo.image;

        glCreateTextures(glTexType(imgVw.viewInfo.viewType), 1, &id);
        view(imgVw);
    }

    void view(T)(T imgVw)
    {
        glTextureView(
            source.id,
            glTexType(imgVw.viewInfo.viewType),
            id,
            glInternalFormat(imgVw.viewInfo.format),
            cast(uint) imgVw.viewInfo.baseLevel,
            cast(uint) imgVw.viewInfo.numLevels,
            cast(uint) imgVw.viewInfo.baseLayer,
            cast(uint) imgVw.viewInfo.numLayers
        );
    }

    ~this()
    {
        glDeleteTextures(1, &id);
    }
}

final class GLImage : Image
{
    uint id;
    uint width_;
    uint height_;
    uint depth_;
    uint iformat;
    ImageType itype;

    this(shared CmdCreateImage imgCrt)
    {
        itype = imgCrt.type;
        auto type = glTexType(imgCrt.type);
        auto format = glInternalFormat(imgCrt.format);
        iformat = format;
        glCreateTextures(type, 1, &id);

        if (imgCrt.type == ImageType.image1D)
        {
            glTextureStorage1D(id, 1, format, imgCrt.width);
            this.width_ = imgCrt.width;
        } else
        if (imgCrt.type == ImageType.image2D)
        {
            glTextureStorage2D(id, 1, format, imgCrt.width, imgCrt.height);
            this.width_ = imgCrt.width;
            this.height_ = imgCrt.height;
        } else
        {
            glTextureStorage3D(id, 1, format, imgCrt.width, imgCrt.height, imgCrt.depth);
            this.width_ = imgCrt.width;
            this.height_ = imgCrt.height;
            this.depth_ = imgCrt.depth;
        }
    }

    ~this()
    {
        glDeleteTextures(1, &id);
    }

    override
    {
        immutable(uint) width() @safe nothrow
        {
            return this.width_;
        }

        immutable(uint) height() @safe nothrow
        {
            return this.height_;
        }

        immutable(uint) depth() @safe nothrow
        {
            return this.depth_;
        }
    }
}

uint glFilter(FilterType f)
{
    final switch (f)
    {
        case FilterType.linear:
            return GL_LINEAR;

        case FilterType.nearest:
            return GL_NEAREST;
    }
}

uint glWrap(SamplerAddressMode address)
{
    final switch (address)
    {
        case SamplerAddressMode.repeat:
            return GL_REPEAT;

        case SamplerAddressMode.mirroredRepeat:
            return GL_MIRRORED_REPEAT;

        case SamplerAddressMode.clampToEdge:
            return GL_CLAMP_TO_EDGE;

        case SamplerAddressMode.clampToBorder:
            return GL_CLAMP_TO_BORDER;

        case SamplerAddressMode.mirrorClampToEdge:
            return GL_MIRROR_CLAMP_TO_EDGE;
    }
}

final class GLSampler : Sampler //
{
    uint id;

    this(shared CmdCreateSampler createSamplerInfo)
    {
        glCreateSamplers(1, &id);
        edit(createSamplerInfo);
    }

    void edit(T)(shared T createSamplerInfo)
    {
        glSamplerParameteri(id, GL_TEXTURE_MIN_FILTER, glFilter(createSamplerInfo.minFilter));
        glSamplerParameteri(id, GL_TEXTURE_MAG_FILTER, glFilter(createSamplerInfo.magFilter));
        glSamplerParameteri(id, GL_TEXTURE_WRAP_S, glWrap(createSamplerInfo.addressModeU));
        glSamplerParameteri(id, GL_TEXTURE_WRAP_T, glWrap(createSamplerInfo.addressModeV));
        glSamplerParameteri(id, GL_TEXTURE_WRAP_R, glWrap(createSamplerInfo.addressModeW));
    }

    ~this()
    {
        glDeleteSamplers(1, &id);
    }
}

final class GLDevice : Device
{   
    import gapi.extensions.utilmessenger;
    import gapi.extensions.backendnative;
    import gapi.extensions.errhandle;
    import gapi.extensions.inputvalidate;

    private
    {
        QueueCreateInfo[] qCreateInfos;
        GLQueue[] queues;
        RCIAllocator allocator;
        LoggingDeviceInfo lgInfo;
        NativeLoggingInfo nlgInfo;
        ErrorLayerInfo errInfo;
        InputValidationLayer ivInfo;
    }

    public
    {
        void handleLayers(ValidationLayerInfo[] layers)
        {
            foreach (e; layers)
            {
                if (!e.enabled)
                    continue;

                switch(e.name)
                {
                    case "GAPIDebugUtilMessenger":
                    {
                        lgInfo = e.loggingDeviceInfo;
                        lgInfo.logger.info("Logger has connected!");
                    }
                    break;

                    case "GPUNativeBackendUtilMessenger":
                    {
                        nlgInfo = e.nativeLoggingInfo;
                        nlgInfo.logger.info("Native logger has connected!");
                    }
                    break;

                    case "GAPIErrorHandle":
                    {
                        errInfo = e.errorLayerInfo;
                    }
                    break;

                    case "GAPIInputValidate":
                    {
                        ivInfo = e.inputValidationLayer;
                    }
                    break;

                    default:
                        break;
                }
            }
        }

        this(GLPhysDevice gpdevice, QueueCreateInfo[] qCreateInfos, ValidationLayerInfo[] vls, RCIAllocator allocator)
        {
            this.allocator = allocator;
            this.qCreateInfos = qCreateInfos;
            queues = makeArray!(GLQueue)(allocator, qCreateInfos.length);

            foreach (size_t i, ref e; queues)
            {
                e = make!(GLQueue)(allocator);
                e.allocator = allocator;
                e.device = this;
                e.flag = gpdevice.fprops[i].queueFlags;
            }

            int err;

            handleLayers(vls);
        }

        Queue[] getQueues()
        {
            Queue[] result = makeArray!(Queue)(allocator, queues.length);
            foreach (i; 0 .. result.length)
            {
                result[i] = cast(Queue) queues[i];
            }

            return result;
        }

        bool rpb = false;
        GLFrameBuffer rpb_fb;
        GLPipeline rpb_pl;

        void globalError(
            string message,
            shared Command command
        )
        {
            debug
            {
                throw new Exception(message, command.file, command.line);
            } else
            {
                throw new Exception(message);
            }
        }

        void globalError(
            shared Command command
        )
        {
            globalError("ATAAS!", command);
        }

        void handleError(
            shared Command command,
            string message
        )
        {
            version(IgnoreErrors)
            {
                return;
            }
            else
            {
                debug
                {
                    throw new Exception(message, command.file, command.line);
                } else
                {
                    throw new Exception(message);
                }
            }
        }

        void handleQueues()
        {
            foreach (ref q; queues)
                handleQueues_modern(q);
        }

        void handleQueueComp_modern(ref GLQueue q)
        {
            import core.atomic;

            foreach (ref pl; q.pl)
            {
                if (ivInfo.callback !is null)
                {
                    ErrorInfo errInfoDelta;
                    ivInfo.callback(
                        cast(shared Queue) q,
                        cast(immutable) pl,
                        errInfoDelta
                    );

                    if (errInfoDelta.code != 0)
                    {
                        if (errInfo.callback !is null)
                        {
                            bool ok = true;
                            shared Command command = cast(shared) errInfoDelta.command;
                            string message = errInfoDelta.message;

                            mixin implErrState!(message, command);

                            errInfo.callback(
                                state,
                                ok
                            );

                            if (!ok)
                            {
                                globalError(command);
                            }
                        } else
                        {
                            handleError(
                                cast(shared) errInfoDelta.command,
                                errInfoDelta.message
                            );
                        }
                    }
                }

                handlePoolComp_modern(cast(shared) q, cast(shared) pl);
                pl.commands = [];
            }
            
            q.hasExecute = true;
            q.pl = [];
        }

        void handlePoolComp_modern(shared GLQueue queue, ref shared CommandPool pl)
        {
            import core.atomic;

            if (pl.commands.length == 0)
                return;

            foreach (shared Command e; cast(shared) pl.commands)
            {
                switch (e.type)
                {
                    case CommandType.createComputePipeline:
                    {

                    }
                    break;

                    default:
                    break;
                }
            }   

            import core.sync.semaphore;

            if (pl.semaphore !is null)
            {
                if (lgInfo.hasLogging && lgInfo.loggingLayer.semaphoreNotifyLayer)
                {
                    lgInfo.logger.info("<...> Semaphore notify");
                }

                (cast(Semaphore) pl.semaphore).notify();
            }

            pl = CommandPool();
        }

        void handleQueues_modern(ref GLQueue q)
        {
            import core.atomic;

            foreach (ref pl; q.pl)
            {
                if (ivInfo.callback !is null)
                {
                    ErrorInfo errInfoDelta;
                    ivInfo.callback(
                        cast(shared Queue) q,
                        cast(immutable) pl,
                        errInfoDelta
                    );

                    if (errInfoDelta.code != 0)
                    {
                        if (errInfo.callback !is null)
                        {
                            bool ok = true;
                            shared Command command = cast(shared) errInfoDelta.command;
                            string message = errInfoDelta.message;

                            mixin implErrState!(message, command);

                            errInfo.callback(
                                state,
                                ok
                            );

                            if (!ok)
                            {
                                globalError(command);
                            }
                        } else
                        {
                            handleError(
                                cast(shared) errInfoDelta.command,
                                errInfoDelta.message
                            );
                        }
                    }
                }

                handlePool_modern(cast(shared) q, cast(shared) pl);
                pl.commands = [];
            }

            q.hasExecute = true;
            q.pl = [];
        }

        void handleQueues_modern(shared GLQueue q)
        {
            import core.atomic;

            foreach (ref pl; q.pl)
            {
                handlePool_modern(q, pl);
            }

            q.hasExecute = true;
        }

        void handlePool_modern(shared GLQueue q, ref shared CommandPool pl)
        {
            import core.atomic;

            // if ((q.flag & pl.cmdFlag) != pl.cmdFlag)
            //     return;

            if (pl.commands.length == 0)
                return;

            foreach (shared Command e; cast(shared) pl.commands)
            {
                switch (e.type)
                {
                    case CommandType.present:
                    {
                        if (e.presentInfo.swapChain is null)
                        {
                            immutable message = "<present> The object for the presentation is wrong";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        version(Windows)
                        {
                            import gapi.gl.extensions.win32wi;
                            GLWin32SwapChain sc = cast(GLWin32SwapChain) e.presentInfo.swapChain;
                            sc.swapBuffers(e.presentInfo);
                        }
                        
                        version(Posix)
                        {
                            import gapi.gl.extensions.pxx11;
                            GLPosixX11SwapChain sc = cast(GLPosixX11SwapChain) e.presentInfo.swapChain;
                            sc.swapBuffers(e.presentInfo);
                        }
                    }
                    break;

                    case CommandType.createFrameBuffer:
                    {
                        if (e.createFrameBufferInfo.frameBuffer is null)
                        {
                            immutable message = "<createFrameBuffer> A pointer to an object was not issued to place a frame buffer into.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }
                            
                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        FrameBuffer fb = make!(GLFrameBuffer)(allocator);
                        atomicStore(*e.createFrameBufferInfo.frameBuffer, cast(shared) fb);
                    }
                    break;

                    case CommandType.createBuffer:
                    {
                        if (e.createBufferInfo.buffer is null)
                        {
                            immutable message = "<createBuffer> A pointer to an object was not issued to place a buffer into.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }
                            
                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);

                                debug
                                {
                                    errInfo.callback(
                                        ErrorState(
                                            e.file,
                                            e.line,
                                            message
                                        ),
                                        ok
                                    );
                                } else
                                {
                                    errInfo.callback(
                                        ErrorState(
                                            __FILE__,
                                            __LINE__,
                                            message
                                        ),
                                        ok
                                    );
                                }

                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        Buffer bf = make!(GLBuffer)(allocator, e.createBufferInfo.type);
                        atomicStore(*e.createBufferInfo.buffer, cast(shared) bf);
                    }
                    break;

                    case CommandType.allocRenderBuffer:
                    {
                        GLBuffer bf = cast(GLBuffer) e.allocRenderBufferInfo.buffer;

                        if (bf is null)
                        {
                            immutable message = "<allocRenderBuffer> The buffer is damaged.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (lgInfo.hasLogging && lgInfo.loggingLayer.warningLayer)
                        {
                            if (e.allocRenderBufferInfo.width == 0 ||
                                e.allocRenderBufferInfo.height == 0)
                            {
                                lgInfo.logger.warning("<allocRenderBuffer> The allocated memory for the render buffer is empty.");
                            }
                        }

                        glNamedRenderbufferStorage(
                            bf.id,
                            GL_RGBA8,
                            e.allocRenderBufferInfo.width,
                            e.allocRenderBufferInfo.height
                        );
                    }
                    break;

                    case CommandType.frameBufferBindBuffer:
                    {
                        GLBuffer bf = cast(GLBuffer) e.frameBufferBindBuffer.buffer;
                        GLFrameBuffer fb = cast(GLFrameBuffer) e.frameBufferBindBuffer.frameBuffer;

                        if (bf is null)
                        {
                            immutable message = "<frameBufferBindBuffer> The frame buffer is damaged.";

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (bf is null)
                        {
                            immutable message = "<frameBufferBindBuffer> The buffer is damaged.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (bf.type != BufferUsage.renderbuffer)
                        {
                            immutable message = "<frameBufferBindBuffer> The buffer is not intended for use under the frame.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        glNamedFramebufferRenderbuffer(fb.id, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, bf.id);
                    }
                    break;

                    case CommandType.clearFrameBuffer:
                    {
                        GLFrameBuffer fb = cast(GLFrameBuffer) e.clearFrameBufferInfo.frameBuffer;

                        if (fb is null)
                        {
                            immutable message = "<clearFrameBuffer> frame buffer is damaged.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        glClearNamedFramebufferfv(
                            fb.id,
                            GL_COLOR,
                            0,
                            cast(const(float)*) e.clearFrameBufferInfo.color.ptr
                        );
                    }
                    break;

                    case CommandType.blitFrameBufferToSurface:
                    {
                        GLFrameBuffer fb = cast(GLFrameBuffer) e.blitFrameBufferToSurfaceInfo.frameBuffer;

                        if (fb is null)
                        {
                            immutable message = "<blitFrameBufferToSurface> frame buffer is damaged.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        glBlitNamedFramebuffer(
                            fb.id,
                            0,
                            e.blitFrameBufferToSurfaceInfo.x,
                            e.blitFrameBufferToSurfaceInfo.y,
                            e.blitFrameBufferToSurfaceInfo.width,
                            e.blitFrameBufferToSurfaceInfo.height,
                            e.blitFrameBufferToSurfaceInfo.x,
                            e.blitFrameBufferToSurfaceInfo.y,
                            e.blitFrameBufferToSurfaceInfo.width,
                            e.blitFrameBufferToSurfaceInfo.height,
                            GL_COLOR_BUFFER_BIT,
                            GL_NEAREST
                        );
                    }
                    break;

                    case CommandType.compileShaderModule:
                    {
                        GLShaderModule shmod;

                        if (e.compileShaderModuleInfo.outputType == CodeType.native)
                        {
                            shmod = make!(GLShaderModule)(allocator,
                                e.compileShaderModuleInfo.stage,
                                e.compileShaderModuleInfo.source,
                                e.compileShaderModuleInfo.status
                            );

                            if (e.compileShaderModuleInfo.status.errorid == 0)
                            {
                                int len = 0;
                                glGetProgramiv(shmod.pid, GL_PROGRAM_BINARY_LENGTH, &len);
                                *e.compileShaderModuleInfo.code = cast(shared void[]) makeArray!(ubyte)(allocator, len);

                                uint format = 0;
                                glGetProgramBinary(shmod.pid, len, null, &format, cast(void*) (*e.compileShaderModuleInfo.code).ptr);
                            }
                        } else
                        {
                            immutable message = "<compileShaderModule> Compilation to SPIRV code is not supported at the moment.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);

                                debug
                                {
                                    errInfo.callback(
                                        ErrorState(
                                            e.file,
                                            e.line,
                                            message
                                        ),
                                        ok
                                    );
                                } else
                                {
                                    errInfo.callback(
                                        ErrorState(
                                            __FILE__,
                                            __LINE__,
                                            message
                                        ),
                                        ok
                                    );
                                }

                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }
                    }
                    break;

                    case CommandType.createShaderModule:
                    {
                        if (e.createShaderModuleInfo.shaderModule is null)
                        {
                            immutable message = "<createShaderModule> shader module pointer is damaged.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (e.createShaderModuleInfo.code.length == 0)
                        {
                            immutable message = "<createShaderModule> shader code is empty.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        *e.createShaderModuleInfo.shaderModule = cast(shared(ShaderModule)) make!(GLShaderModule)(allocator,
                            e.createShaderModuleInfo.codeType,
                            e.createShaderModuleInfo.stage,
                            e.createShaderModuleInfo.code,
                            e.createShaderModuleInfo.status,
                            allocator
                        );
                    }
                    break;

                    case CommandType.destroyShaderModule:
                    {
                        dispose(allocator, *e.destroyShaderModuleInfo.shaderModule);
                        e.destroyShaderModuleInfo.shaderModule = null;
                    }
                    break;

                    case CommandType.createPipeline:
                    {
                        if (e.createPipelineInfo.pipeline is null)
                        {
                            immutable message = "<createPipeline> The pointer to the pipeline is damaged.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        *e.createPipelineInfo.pipeline = cast(shared) make!(GLPipeline)(allocator, e.createPipelineInfo, allocator);
                    }
                    break;

                    case CommandType.allocBuffer:
                    {
                        GLBuffer buffer = cast(GLBuffer) e.allocBufferInfo.buffer;

                        if (buffer is null)
                        {
                            immutable message = "<allocBuffer> The buffer is damaged.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        buffer.alloc (e.allocBufferInfo.size);
                    }
                    break;

                    case CommandType.bufferSetData:
                    {
                        GLBuffer buffer = cast(GLBuffer) e.buffSetDataInfo.buffer;

                        if (buffer is null)
                        {
                            immutable message = "<bufferSetData> The pointer to the data with the buffer is corrupted.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }
                            
                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                debug
                                {
                                    errInfo.callback(
                                        ErrorState(
                                            e.file,
                                            e.line,
                                            message
                                        ),
                                        ok
                                    );
                                } else
                                {
                                    errInfo.callback(
                                        ErrorState(
                                            __FILE__,
                                            __LINE__,
                                            message
                                        ),
                                        ok
                                    );
                                }

                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (e.buffSetDataInfo.offset + e.buffSetDataInfo.size > buffer.length)
                        {
                            immutable message = "<buffSetData> The size of the data block exceeds the size of the buffer.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (e.buffSetDataInfo.size > e.buffSetDataInfo.data.length)
                        {
                            immutable message = "<buffSetData> The size of the data block exceeds the size of the input data.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        glNamedBufferSubData(
                            buffer.id,
                            cast(GLintptr) e.buffSetDataInfo.offset,
                            cast(GLsizeiptr) e.buffSetDataInfo.size,
                            cast(const(void)*) e.buffSetDataInfo.data.ptr
                        );
                    }
                    break;

                    case CommandType.mapBuffer:
                    {
                        import std.traits : EnumMembers;
                        GLBuffer buffer = cast(GLBuffer) e.mapBufferInfo.buffer;

                        if (buffer is null)
                        {
                            immutable message = "<mapBuffer> The pointer to the data with the buffer is corrupted.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }
                            
                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                debug
                                {
                                    errInfo.callback(
                                        ErrorState(
                                            e.file,
                                            e.line,
                                            message
                                        ),
                                        ok
                                    );
                                } else
                                {
                                    errInfo.callback(
                                        ErrorState(
                                            __FILE__,
                                            __LINE__,
                                            message
                                        ),
                                        ok
                                    );
                                }

                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        int access;

                        if (buffer.hasMap)
                        {
                            if (lgInfo.hasLogging)
                            {
                                lgInfo.logger.warning("The buffer has already been mapped.");
                                continue;
                            }
                        }

                        int glAcces(MapAccess a)
                        {
                            final switch (a)
                            {
                                case MapAccess.readBit:
                                    return GL_MAP_READ_BIT;

                                case MapAccess.writeBit:
                                    return GL_MAP_WRITE_BIT;
                            }
                        }

                        foreach (te; EnumMembers!MapAccess)
                        {
                            if ((e.mapBufferInfo.access & te) == te)
                            {
                                access |= glAcces(te);
                            }
                        }

                        buffer.hasMap = true;

                        *e.mapBufferInfo.space =
                            cast(shared) glMapNamedBufferRange(
                                buffer.id,
                                cast(int) e.mapBufferInfo.offset,
                                e.mapBufferInfo.length,
                                access
                            )[e.mapBufferInfo.offset .. e.mapBufferInfo.length];
                        //);
                    }
                    break;

                    case CommandType.unmapBuffer:
                    {
                        GLBuffer buffer = cast(GLBuffer) e.unmapBufferInfo.buffer;

                        if (buffer is null)
                        {
                            immutable message = "<unmapBuffer> The pointer to the data with the buffer is corrupted.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }
                            
                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                debug
                                {
                                    errInfo.callback(
                                        ErrorState(
                                            e.file,
                                            e.line,
                                            message
                                        ),
                                        ok
                                    );
                                } else
                                {
                                    errInfo.callback(
                                        ErrorState(
                                            __FILE__,
                                            __LINE__,
                                            message
                                        ),
                                        ok
                                    );
                                }

                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (buffer.hasMap)
                        {
                            buffer.hasMap = false;
                            glUnmapNamedBuffer(buffer.id);
                        } else
                        {
                            if (lgInfo.hasLogging)
                            {
                                debug
                                {
                                    import std.conv : to;

                                    lgInfo.logger.info("In `" ~ e.file ~ ":" ~ e.line.to!string);
                                }

                                lgInfo.logger.warning("The buffer has already been unmapped.");
                            }
                        }
                    }
                    break;

                    case CommandType.renderPassBegin:
                    {
                        rpb = true;
                        rpb_fb = cast(GLFrameBuffer) e.renderPassBegin.frameBuffer;

                        if (rpb_fb is null)
                        {
                            immutable message = "<renderPassBegin> The framebuffer is damaged.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        glClearNamedFramebufferfv(rpb_fb.id, GL_COLOR, 0, cast(float*) e.renderPassBegin.clearColor.ptr);
                    }
                    break;

                    case CommandType.createImage:
                    {
                        if (e.createImageInfo.image is null)
                        {
                            immutable message = "<createImage> The pointer to the image is damaged.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        GLImage img = make!(GLImage)(allocator, e.createImageInfo);
                        *e.createImageInfo.image = cast(shared Image) img;
                    }
                    break;

                    case CommandType.bindImageMemory:
                    {
                        GLImage img = cast(GLImage) e.bindImageMemoryInfo.image;

                        if (img is null)
                        {
                            immutable message = "<bindImageMemory> The image descriptor is corrupted.";

                            if (lgInfo.hasLogging && lgInfo.loggingLayer.errorLayer)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                
                                mixin implErrState!(message, e);

                                errInfo.callback(
                                    state,
                                    ok
                                );

                                if (!ok)
                                {
                                    globalError(e);
                                }
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (e.bindImageMemoryInfo.length + e.bindImageMemoryInfo.offset > e.bindImageMemoryInfo.data.length)
                        {
                            immutable message = "The size in the arguments is larger than the array itself.";
                            if (lgInfo.hasLogging && lgInfo.logger.log !is null)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );
                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (img.itype == ImageType.image1D)
                        {
                            glTextureSubImage1D(
                                img.id,
                                1,
                                0,
                                img.width,
                                GL_RGBA,
                                GL_UNSIGNED_BYTE,
                                cast(const(void)*) e
                                    .bindImageMemoryInfo
                                    .data[e.bindImageMemoryInfo.offset .. e.bindImageMemoryInfo.offset + e.bindImageMemoryInfo.length].ptr
                            );
                        } else
                        if (img.itype == ImageType.image2D)
                        {
                            glTextureSubImage2D(
                                img.id,
                                0, 0, 0,
                                img.width, img.height,
                                GL_RGBA,
                                GL_UNSIGNED_BYTE,
                                cast(const(void)*) e
                                    .bindImageMemoryInfo
                                    .data[e.bindImageMemoryInfo.offset .. e.bindImageMemoryInfo.offset + e.bindImageMemoryInfo.length].ptr
                            );
                        }
                    }
                    break;

                    case CommandType.createSampler:
                    {
                        if (e.createSamplerInfo.sampler is null)
                        {
                            immutable message = "<createSampler> The pointer to the sampler is damaged.";
                            
                            if (lgInfo.hasLogging && lgInfo.logger.log !is null)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );
                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        GLSampler smp = make!(GLSampler)(allocator, e.createSamplerInfo);
                        *e.createSamplerInfo.sampler = cast(shared Sampler) smp;
                    }
                    break;

                    case CommandType.editSampler:
                    {
                        GLSampler smp = cast(GLSampler) e.editSamplerInfo.sampler;

                        if (smp is null)
                        {
                            immutable message = "<editSampler> The handle to the sampler is damaged.";

                            if (lgInfo.hasLogging && lgInfo.logger.log !is null)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );
                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        smp.edit(e.editSamplerInfo);
                    }
                    break;

                    case CommandType.draw:
                    {
                        GLPipeline pp = cast(GLPipeline) e.drawInfo.pipeline;
                        GLBuffer vb = cast(GLBuffer) e.drawInfo.vertexBuffer;

                        if (pp is null)
                        {
                            immutable message = "<draw> The handle to the pipeline is damaged.";

                            if (lgInfo.hasLogging && lgInfo.logger.log !is null)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );
                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (vb is null)
                        {
                            immutable message = "<draw> The handle to the vertices is damaged.";

                            if (lgInfo.hasLogging && lgInfo.logger.log !is null)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );
                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        glEnable(GL_SCISSOR_TEST);

                        auto vv = pp.pipelineInfo.viewportState.viewport;
                        auto sc = pp.pipelineInfo.viewportState.scissor;
                        glViewport(cast(int) vv.x, cast(int) vv.y, cast(int) vv.width, cast(int) vv.height);
                        glScissor(cast(int) sc.offset[0], cast(int) sc.offset[1], cast(int) sc.extent[0], cast(int) sc.extent[1]);

                        if (pp.pipelineInfo.rasterization.depthClampEnable)
                            glEnable(GL_DEPTH_CLAMP);
                        else
                            glDisable(GL_DEPTH_CLAMP);

                        uint glPMode(PolygonMode pmode)
                        {
                            final switch(pmode)
                            {
                                case PolygonMode.point:
                                    return GL_POINT;

                                case PolygonMode.line:
                                    return GL_LINE;

                                case PolygonMode.fill:
                                    return GL_FILL;
                            }
                        }

                        glPolygonMode(GL_FRONT_AND_BACK, glPMode(pp.pipelineInfo.rasterization.polygonMode));
                        glLineWidth(pp.pipelineInfo.rasterization.lineWidth);

                        if (pp.pipelineInfo.colorBlendAttachment.blendEnable)
                            glEnable(GL_BLEND);
                        else
                            glDisable(GL_BLEND);

                        int glBlendFactor(BlendFactor factor)
                        {
                            if (factor == BlendFactor.Zero)
                                return GL_ZERO;
                            else
                            if (factor == BlendFactor.One)
                                return GL_ONE;
                            else
                            if (factor == BlendFactor.SrcColor)
                                return GL_SRC_COLOR;
                            else
                            if (factor == BlendFactor.DstColor)
                                return GL_DST_COLOR;
                            else
                            if (factor == BlendFactor.OneMinusSrcColor)
                                return GL_ONE_MINUS_SRC_COLOR;
                            else
                            if (factor == BlendFactor.OneMinusDstColor)
                                return GL_ONE_MINUS_DST_COLOR;
                            else
                            if (factor == BlendFactor.SrcAlpha)
                                return GL_SRC_ALPHA;
                            else
                            if (factor == BlendFactor.DstAlpha)
                                return GL_DST_ALPHA;
                            else
                            if (factor == BlendFactor.OneMinusSrcAlpha)
                                return GL_ONE_MINUS_SRC_ALPHA;
                            else
                            if (factor == BlendFactor.OneMinusDstAlpha)
                                return GL_ONE_MINUS_DST_ALPHA;

                            return 0;
                        }

                        glBlendFuncSeparate(
                            glBlendFactor(pp.pipelineInfo.colorBlendAttachment.srcColorBlendFactor),
                            glBlendFactor(pp.pipelineInfo.colorBlendAttachment.dstColorBlendFactor),
                            glBlendFactor(pp.pipelineInfo.colorBlendAttachment.srcAlphaBlendFactor),
                            glBlendFactor(pp.pipelineInfo.colorBlendAttachment.dstAlphaBlendFactor)
                        );

                        uint glBlendOp(BlendOp op)
                        {
                            final switch(op)
                            {
                                case BlendOp.add:
                                    return GL_FUNC_ADD;

                                case BlendOp.subtract:
                                    return GL_FUNC_SUBTRACT;

                                case BlendOp.reverseSubtract:
                                    return GL_FUNC_REVERSE_SUBTRACT;

                                case BlendOp.min:
                                    return GL_MIN;

                                case BlendOp.max:
                                    return GL_MAX;
                            }
                        }

                        glBlendEquationSeparate(
                            glBlendOp(pp.pipelineInfo.colorBlendAttachment.colorBlendOp),
                            glBlendOp(pp.pipelineInfo.colorBlendAttachment.alphaBlendOp)
                        );

                        if (pp.pipelineInfo.colorAttachment.sampleEnable)
                            glEnable(GL_MULTISAMPLE);
                        else
                            glDisable(GL_MULTISAMPLE);

                        if (vb !is null)
                        {
                            glVertexArrayVertexBuffer(
                                pp.vinfo,
                                0,
                                vb.id,
                                0,
                                pp.pipelineInfo.vertexInput.stride
                            );
                        }

                        glBindFramebuffer(GL_FRAMEBUFFER, rpb_fb.id);
                        glBindProgramPipeline((cast(GLPipeline) e.drawInfo.pipeline).id);

                        uint bid = 0;
                        foreach (ef; pp.pipelineInfo.writeDescriptions)
                        {
                            if (ef.type == WriteDescriptType.uniform)
                            {
                                uint it = 0;

                                foreach (md; pp.pipelineInfo.stages)
                                {
                                    if (ef.uniform.stageFlags == md.stage)
                                    {
                                        immutable eg = pp.stages[it];
                                        GLBuffer bg = cast(GLBuffer) ef.uniform.buffer;

                                        glUniformBlockBinding(eg.pid, ef.binding, bid);

                                        glBindBufferRange(
                                            GL_UNIFORM_BUFFER,
                                            bid,
                                            bg.id,
                                            cast(GLintptr) ef.uniform.offset,
                                            cast(GLsizeiptr) ef.uniform.size
                                        );

                                        bid += 1;
                                    }

                                    it++;
                                }
                            } else
                            if (ef.type == WriteDescriptType.imageSampler)
                            {
                                if (ef.imageView.sampler is null)
                                {
                                    lgInfo.logger.warning("Sampler is empty!");
                                    continue;
                                }

                                GLSampler smp = cast(GLSampler) ef.imageView.sampler;
                                GLImage img = cast(GLImage) ef.imageView.image;
                                glBindSampler(ef.binding, smp.id);
                                glBindTextureUnit(ef.binding, img.id);
                            }
                        }

                        static uint glTopology(PrimitiveTopology type)
                        {
                            final switch (type)
                            {
                                case PrimitiveTopology.lines:
                                    return GL_LINES;

                                case PrimitiveTopology.lineStrip:
                                    return GL_LINE_STRIP;

                                case PrimitiveTopology.points:
                                    return GL_POINTS;

                                case PrimitiveTopology.triangles:
                                    return GL_TRIANGLES;

                                case PrimitiveTopology.trianglesFan:
                                    return GL_TRIANGLE_FAN;
                            }
                        }

                        immutable topology = glTopology(e.drawInfo.topology);

                        if (e.drawInfo.elementBuffer !is null)
                        {
                            GLBuffer ibuff = cast(GLBuffer) e.drawInfo.elementBuffer;

                            glVertexArrayElementBuffer(pp.vinfo, ibuff.id);

                            glBindVertexArray((cast(GLPipeline) e.drawInfo.pipeline).vinfo);
                            glDrawElements(topology, e.drawInfo.count, GL_UNSIGNED_INT, null);
                        } else
                        {
                            glBindVertexArray((cast(GLPipeline) e.drawInfo.pipeline).vinfo);
                            glDrawArrays(topology, 0, e.drawInfo.count);
                        }
                    }
                    break;

                    case CommandType.renderPassEnd:
                    {
                        rpb = false;
                    }
                    break;

                    case CommandType.copyBuffer:
                    {
                        GLBuffer    rb = cast(GLBuffer) e.copyBufferInfo.read,
                                    wb = cast(GLBuffer) e.copyBufferInfo.write;

                        if (rb is null)
                        {
                            immutable message = "<copyBuffer> The handle on the read buffer is corrupted.";

                            if (lgInfo.hasLogging && lgInfo.logger.log !is null)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );
                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (wb is null)
                        {
                            immutable message = "<copyBuffer> The handle on the write buffer is corrupted.";

                            if (lgInfo.hasLogging && lgInfo.logger.log !is null)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );
                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (e.copyBufferInfo.srcOffset + e.copyBufferInfo.size > rb.length)
                        {
                            immutable message = "<copyBuffer> The size of the data block from the read buffer is smaller than the region in the arguments suggests.";

                            if (lgInfo.hasLogging && lgInfo.logger.log !is null)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );
                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (e.copyBufferInfo.dstOffset + e.copyBufferInfo.size > wb.length)
                        {
                            immutable message = "<copyBuffer> The size of the data block from the write buffer is smaller than the region in the arguments suggests.";

                            if (lgInfo.hasLogging && lgInfo.logger.log !is null)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );
                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        glCopyNamedBufferSubData(
                            rb.id, wb.id,
                            cast(GLintptr) e.copyBufferInfo.srcOffset,
                            cast(GLintptr) e.copyBufferInfo.dstOffset,
                            cast(GLsizeiptr) e.copyBufferInfo.size
                        );
                    }
                    break;

                    case CommandType.pipelineEdit:
                    {
                        import std.typecons : Nullable;

                        GLPipeline pip = cast(GLPipeline) e.pipelineEditInfo.pipeline;

                        if (pip is null)
                        {
                            immutable message = "<pipelineEdit> The handle to the pipeline is damaged.";

                            if (lgInfo.hasLogging && lgInfo.logger.log !is null)
                            {
                                lgInfo.logger.error(message);
                            }

                            if (errInfo.callback !is null)
                            {
                                bool ok = true;
                                mixin implErrState!(message, e);
                                errInfo.callback(
                                    state,
                                    ok
                                );
                                if (!ok)
                                    globalError(e);
                            } else
                            {
                                handleError(e, message);
                            }
                        }

                        if (!(cast(Nullable!ViewportState) e.pipelineEditInfo.state.viewportState).isNull)
                            pip.pipelineInfo.viewportState = cast(ViewportState) (cast(Nullable!ViewportState) e.pipelineEditInfo.state.viewportState).get;

                        if (!(cast(Nullable!ColorBlendAttachmentState) e.pipelineEditInfo.state.colorBlendAttachment).isNull)
                            pip.pipelineInfo.colorBlendAttachment = (cast(Nullable!ColorBlendAttachmentState) e.pipelineEditInfo.state.colorBlendAttachment).get;
                    }
                    break;

                    case CommandType.destroyBuffer:
                    {
                        GLBuffer buffer = cast(GLBuffer) *e.destroyBufferInfo.buffer;
                        dispose(allocator, buffer);

                        *e.destroyBufferInfo.buffer = null;
                    }
                    break;

                    case CommandType.destroySampler:
                    {
                        GLSampler sampler = cast(GLSampler) *e.destroySamplerInfo.sampler;
                        dispose(allocator, sampler);

                        *e.destroySamplerInfo.sampler = null;
                    }
                    break;

                    case CommandType.destroyImage:
                    {
                        GLImage image = cast(GLImage) *e.destroyImageInfo.image;
                        dispose(allocator, image);

                        *e.destroyImageInfo.image = null;
                    }
                    break;

                    case CommandType.destroyPipeline:
                    {
                        GLPipeline pipeline = cast(GLPipeline) *e.destroyPipelineInfo.pipeline;
                        dispose(allocator, pipeline);

                        *e.destroyPipelineInfo.pipeline = null;
                    }
                    break;

                    case CommandType.destroyFrameBuffer:
                    {
                        GLFrameBuffer fb = cast(GLFrameBuffer) *e.destroyFrameBufferInfo.frameBuffer;
                        dispose(allocator, fb);

                        *e.destroyFrameBufferInfo.frameBuffer = null;
                    }
                    break;

                    case CommandType.createImageView:
                    {
                        GLImageView iv = make!GLImageView(allocator, e.createImageViewInfo);
                        *e.createImageViewInfo.imageView = cast(shared) iv;
                    }
                    break;

                    case CommandType.updateImageView:
                    {
                        GLImageView iv = cast(GLImageView) e.updateImageViewInfo.imageView;
                        iv.view(e.updateImageViewInfo);
                    }
                    break;

                    case CommandType.extensionCommand:
                    {
                        switch (e.extensionInfo.extension)
                        {
                            case "GAPIVideoDecode":
                            {
                                //handleVideoDecodeCommand(e);
                            }
                            break;

                            default:
                            {

                            }
                            break;
                        }
                    }
                    break;

                    default:
                        break;
                }
            }

            import core.sync.semaphore;

            if (pl.semaphore !is null)
            {
                if (lgInfo.hasLogging && lgInfo.loggingLayer.semaphoreNotifyLayer)
                {
                    lgInfo.logger.info("<...> Semaphore notify");
                }

                (cast(Semaphore) pl.semaphore).notify();
            }

            pl = CommandPool();
        }
    }

    void handleVideoDecodeCommand(Command command)
    {
        // video decode
    }
}

version(Windows)
{
    class WindowException : Exception
    {
        import std.conv : to;
        
        this(ulong errorID) @trusted
        {
            LPSTR messageBuffer = null;

            size_t size = FormatMessageA(
                FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                null, 
                cast(uint) errorID, 
                MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US), 
                cast(LPSTR) &messageBuffer, 
                0, 
                null);
                            
        
            super("[WinAPI] " ~ messageBuffer.to!string);
        }
    }

    struct __gapi_twnd_info
    {
        public
        {
            HMODULE hInstance;
            HANDLE wnd;
            HDC dc;
            HGLRC ctx;
            PIXELFORMATDESCRIPTOR pfd;

            ubyte error;
        }

        static __gapi_twnd_info err(ubyte error)
        {
            return __gapi_twnd_info(null, null, null, null, PIXELFORMATDESCRIPTOR.init, error);
        }
    }

    void __gapi_dst_twnd(__gapi_twnd_info info)
    {
        if (info.error != 0)
            return;
            
        if (info.ctx !is null)
            wglDeleteContext(info.ctx);

        if (info.dc !is null)
            ReleaseDC(info.wnd, info.dc);

        if (info.wnd !is null)
            DestroyWindow(info.wnd);

        UnregisterClassA("__GAPI_GET_PROPERTIES", info.hInstance);
    }

    __gapi_twnd_info __gapi_init_wgl()
    {
        import std.traits : Signed;

        extern(Windows) auto _wndProc(HWND hWnd, uint message, WPARAM wParam, LPARAM lParam)
        {
            return DefWindowProc(hWnd, message, wParam, lParam);
        }

        alias WinFun = extern (Windows) Signed!size_t function(void*, uint, size_t, Signed!size_t) nothrow @system;

        auto hInstance = GetModuleHandle(null);
        WNDCLASSEX wc;

        wc.cbSize = wc.sizeof;
        wc.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
        wc.lpfnWndProc = cast(WinFun) &_wndProc;
        wc.hInstance = hInstance;
        wc.hCursor = LoadCursor(null, IDC_ARROW);
        wc.lpszClassName = "__GAPI_GET_PROPERTIES";

        RegisterClassEx(&wc);
    
        auto twnd = CreateWindow(   "__GAPI_GET_PROPERTIES", "__GAPI_GET_PROPERTIES",
                                    WS_CLIPSIBLINGS | 
                                    WS_CLIPCHILDREN | WS_THICKFRAME,
                                    1, 1, 128, 
                                    128, null, null, 
                                    hInstance, null);

        if (twnd is null)
            throw new WindowException(GetLastError());

        PIXELFORMATDESCRIPTOR pfd;
        pfd.nSize = PIXELFORMATDESCRIPTOR.sizeof;
        pfd.nVersion = 1;
        pfd.dwFlags = PFD_DOUBLEBUFFER | PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cRedBits = cast(ubyte) 8;
        pfd.cGreenBits = cast(ubyte) 8;
        pfd.cBlueBits = cast(ubyte) 8;
        pfd.cAlphaBits = cast(ubyte) 8;
        pfd.cDepthBits = cast(ubyte) 24;
        pfd.cStencilBits = cast(ubyte) 8;
        pfd.cColorBits = cast(ubyte) 32;
        pfd.iLayerType = PFD_MAIN_PLANE;

        auto deviceHandle = GetDC(twnd);
        auto chsPixel = ChoosePixelFormat(deviceHandle, &pfd);
        if (chsPixel == 0)
        {
            return __gapi_twnd_info.err(4);
        }

        if (!SetPixelFormat(deviceHandle, chsPixel, &pfd))
        {
            return __gapi_twnd_info.err(5);
        }

        auto ctx = wglCreateContext(deviceHandle);
        if (!wglMakeCurrent(deviceHandle, ctx))
        {
            return __gapi_twnd_info.err(6);
        }

        initWGL();

        return __gapi_twnd_info(hInstance, twnd, deviceHandle, ctx, pfd, 0);
    }

    __gapi_twnd_info __gapi_twnd(bool full = true)
    {
        auto info = __gapi_init_wgl();
        if (info.error != 0)
            return info;

        if (!full)
            return info;

        int[] iattrib =  
        [
            WGL_SUPPORT_OPENGL_ARB, true,
            WGL_DRAW_TO_WINDOW_ARB, true,
            WGL_DOUBLE_BUFFER_ARB, true,
            WGL_RED_BITS_ARB, 8,
            WGL_GREEN_BITS_ARB, 8,
            WGL_BLUE_BITS_ARB, 8,
            WGL_ALPHA_BITS_ARB, 8,
            WGL_DEPTH_BITS_ARB, 24,
            WGL_COLOR_BITS_ARB, 32,
            WGL_STENCIL_BITS_ARB, 8,
            WGL_PIXEL_TYPE_ARB, WGL_TYPE_RGBA_ARB,
            0
        ];

        uint nNumFormats;
        int[20] nPixelFormat;
        wglChoosePixelFormatARB(
            info.dc,   
            iattrib.ptr, 
            null,
            20, nPixelFormat.ptr,
            &nNumFormats
        );

        bool isSuccess = false;
        foreach (i; 0 .. nNumFormats)
        {
            DescribePixelFormat(info.dc, nPixelFormat[i], info.pfd.sizeof, &info.pfd);
            if (SetPixelFormat(info.dc, nPixelFormat[i], &info.pfd) == true)
            {
                isSuccess = true;
                break;
            }
        }

        if (!isSuccess)
        {
            __gapi_dst_twnd(info);

            return __gapi_twnd_info.err(2);
        }

        // Use deprecated functional
        int[] attrib =  
        [
            WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
            WGL_CONTEXT_MINOR_VERSION_ARB, 2,
            WGL_CONTEXT_FLAGS_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
            WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
            0
        ];

        auto mctx = wglCreateContextAttribsARB(     info.dc, 
                                                    null, 
                                                    attrib.ptr);

        if (mctx is null)
        {
            attrib =  
            [
                WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
                WGL_CONTEXT_MINOR_VERSION_ARB, 2,
                WGL_CONTEXT_FLAGS_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                0
            ];

            mctx = wglCreateContextAttribsARB(      info.dc, 
                                                    null, 
                                                    attrib.ptr);

            if (mctx is null)
            {
                __gapi_dst_twnd(info);

                return __gapi_twnd_info.err(1);
            }
        }

        wglMakeCurrent(null, null);
        wglDeleteContext(info.ctx);

        if (!wglMakeCurrent(info.dc, mctx))
        {
            __gapi_dst_twnd(info);

            return __gapi_twnd_info.err(3);
        }

        info.ctx = mctx;

        return info;
    }
}

final class GLPhysDevice : PhysDevice
{
    private
    {
        void glInfo(ref PhysDeviceProperties prt)
        {
            import std.conv : to;

            if (handle is null)
            {
                prt.deviceName = glGetString(GL_RENDERER).to!string;
                prt.driverVersion = glGetString(GL_VERSION).to!string;
            }

            glGetIntegerv(GL_MAX_FRAMEBUFFER_LAYERS, cast(int*) &prt.limits.maxFramebufferLayers);
            glGetIntegerv(GL_MAX_TEXTURE_SIZE, cast(int*) &prt.limits.maxTextureSize);
            glGetIntegerv(GL_MAX_VERTEX_ATTRIBS, cast(int*) &prt.limits.maxVertexInputAttribs);
            glGetIntegerv(GL_MAX_VERTEX_OUTPUT_COMPONENTS, cast(int*) &prt.limits.maxVertexOutputComponents);
            glGetIntegerv(GL_MAX_GEOMETRY_INPUT_COMPONENTS, cast(int*) &prt.limits.maxGeometryInputComponents);
            glGetIntegerv(GL_MAX_GEOMETRY_OUTPUT_COMPONENTS, cast(int*) &prt.limits.maxGeometryOutputComponents);
            glGetIntegerv(GL_MAX_FRAGMENT_INPUT_COMPONENTS, cast(int*) &prt.limits.maxFragmentInputComponents);
            glGetIntegerv(GL_MAX_VERTEX_UNIFORM_BLOCKS, cast(int*) &prt.limits.maxVertexUniformBlocks);
            glGetIntegerv(GL_MAX_FRAGMENT_UNIFORM_BLOCKS, cast(int*) &prt.limits.maxFragmentUniformBlocks);
            prt.limits.maxFragmentOutputComponents = 4;
            glGetIntegerv(GL_MAX_COMPUTE_SHARED_MEMORY_SIZE, cast(int*) &prt.limits.maxComputeSharedMemorySize);
            glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 0, cast(int*) &prt.limits.maxComputeWorkGroupCount[0]);
            glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 1, cast(int*) &prt.limits.maxComputeWorkGroupCount[1]);
            glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 2, cast(int*) &prt.limits.maxComputeWorkGroupCount[2]);
            glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS, cast(int*) &prt.limits.maxComputeWorkGroupInvocations);
            glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 0, cast(int*) &prt.limits.maxComputeWorkGroupSize[0]);
            glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 1, cast(int*) &prt.limits.maxComputeWorkGroupSize[1]);
            glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 2, cast(int*) &prt.limits.maxComputeWorkGroupSize[2]);
            glGetIntegerv(GL_SUBPIXEL_BITS, cast(int*) &prt.limits.subPixelPrecisionBits);
            glGetIntegerv(GL_MAX_VIEWPORTS, cast(int*) &prt.limits.maxViewports);

            string[] attribs = cstrlist(glGetString(GL_EXTENSIONS));

            uint factors;
            immutable needFactors = 4;

            foreach (attrib; attribs)
            {
                switch (attrib)
                {
                    case "ARB_direct_state_access":
                        factors++;
                    break;

                    case "GL_ARB_sampler_objects":
                        factors++;
                    break;

                    case "GL_ARB_separate_shader_objects":
                        factors++;
                    break;

                    case "GL_ARB_get_program_binary":
                        factors++;
                    break;

                    case "GL_ARB_geometry_shader4":
                        prt.features.geometryShader = true;
                    break;

                    case "GL_ARB_tessellation_shader":
                        prt.features.tessellationShader = true;
                    break;

                    case "GL_ARB_multi_draw_indirect":
                        prt.features.multiDrawIndirect = true;
                    break;

                    case "GL_ARB_texture_compression":
                        prt.features.textureCompression = true;
                    break;

                    case "GL_ARB_texture_compression_bptc":
                        prt.features.textureCompressionBPCT = true;
                    break;

                    case "GL_ARB_texture_compression_rgtc":
                        prt.features.textureCompressionRGTC = true;
                    break;

                    case "GL_ARB_gpu_shader_int64":
                        prt.features.shaderInt64 = true;
                    break;

                    case "GL_ARB_gpu_shader_fp64,":
                        prt.features.shaderFloat64 = true;
                    break;

                    case "GL_ARB_cull_distance":
                        prt.features.shaderCullDistance = true;
                    break;

                    case "GL_ARB_clip_control":
                        prt.features.shaderClipDistance = true;
                    break;

                    case "GL_ARB_gl_spirv":
                        prt.features.spirv = true;
                    break;

                    case "GL_ARB_viewport_array":
                    {
                        prt.features.scissor = true;
                    }
                    break;

                    default:
                        break;
                }
            }

            if (factors < needFactors)
            {
                prt.avalibleForCreation = true;
            }
        }

        version(Windows)
        {
            DISPLAY_DEVICE dev;
            __gapi_gl_dinfo dinfo;

            void byNVML(ref PhysDeviceProperties prt)
            {
                import std.conv : to;

                char[] name = makeArray!(char)(allocator, 80);

                nvmlDeviceGetName(handle, name.ptr, 80);
                prt.deviceName = name.to!(string);

                nvmlPciInfo_t pinfo;
                nvmlDeviceGetPciInfo_v3(handle, &pinfo);
                prt.deviceID = pinfo.pciDeviceId;

                nvmlSystemGetDriverVersion(name.ptr, 80);
                prt.driverVersion = name.to!(string);

                allocator.deallocate(cast(void[]) name);
            }

            void byDInfo(ref PhysDeviceProperties prt)
            {
                if (dinfo.type == __gapi_gl_dev_type.discrete_nvidia)
                {
                    nvmlDeviceGetHandleByIndex_v2(0, &this.handle);
                    byNVML(prt);
                    prt.type = PhysDeviceType.discrete;
                } else
                {
                    prt.type = PhysDeviceType.integrate;
                }
            }

            PhysDeviceProperties getPropertiesWinImpl() @trusted
            {
                import std.conv : to;
                import std.traits : Signed;

                PhysDeviceProperties prt;

                auto info = __gapi_twnd(!(dinfo.type == __gapi_gl_dev_type.integrated_intel)); 
                scope(exit) __gapi_dst_twnd(info);

                if (info.error != 0)
                {
                    throw new UnsupportException(UnsupportType.interfaceOutdated, info.error);
                }
                
                if (loadOpenGL() < 11)
                {
                    throw new UnsupportException(UnsupportType.interfaceOutdated);
                }

                prt.deviceName = glGetString(GL_RENDERER).to!string;
                prt.driverVersion = glGetString(GL_VERSION).to!string;

                glInfo(prt);

                return prt;
            }
        }

        version(Posix)
        {
            Display* dpy;

            string c_str(char[] str)
            {
                size_t i = 0;
                while (str[++i] != '\0') {}

                return cast(string) str[0 .. i];
            }

            PhysDeviceProperties getPropertiesPosixImpl() @trusted
            {
                import bindbc.opengl;
                import std.conv : to;

                dpy = XOpenDisplay(null);

                PhysDeviceProperties prt;

                if (handle !is null)
                {
                    char[] name = makeArray!(char)(allocator, 80);

                    nvmlDeviceGetName(handle, name.ptr, 80);
                    prt.deviceName = c_str(cast(char[]) name.to!string);

                    nvmlPciInfo_t pinfo;
                    nvmlDeviceGetPciInfo_v3(handle, &pinfo);
                    prt.deviceID = pinfo.pciDeviceId;

                    nvmlSystemGetDriverVersion(name.ptr, 80);
                    prt.driverVersion = c_str(cast(char[]) name.to!string);

                    allocator.deallocate(cast(void[]) name);
                }

                prt.vendor = glXGetClientString(dpy, 1).to!string;

                int cfglen;
                GLXFBConfig* cfgs = glXGetFBConfigs(dpy, 0, &cfglen);

                int maxW, maxH, maxID;
                uint smax;
                foreach (i; 0 .. cfglen)
                {
                    int val, sval;
                    glXGetFBConfigAttrib(dpy, cfgs[i], GLX_MAX_PBUFFER_WIDTH, &val);
                    glXGetFBConfigAttrib(dpy, cfgs[i], GLX_SAMPLES, &sval);

                    if (val > maxW)
                    {
                        maxW = val;
                        maxID = i;
                    }

                    if (sval > smax)
                        smax = sval;
                }

                glXGetFBConfigAttrib(dpy, cfgs[maxID], GLX_MAX_PBUFFER_HEIGHT, &maxH);

                PhysDeviceLimits limits;
                limits.maxFramebufferWidth = maxW;
                limits.maxFramebufferHeight = maxH;
                limits.sampleCounts = smax;

                prt.type = handle is null ? PhysDeviceType.integrate : PhysDeviceType.discrete;
                prt.limits = limits;

                Window ww = XCreateSimpleWindow(dpy, RootWindow(dpy, 0),
                    0, 0, 32, 32, 0, 0, 0);
                auto ctx = glXCreateNewContext(dpy, cfgs[maxID], GLX_RGBA_TYPE, null, true);
                glXMakeCurrent(dpy, ww, ctx);

                loadOpenGL();

                glInfo(prt);

                unloadOpenGL();

                glXDestroyContext(dpy, ctx);
                XDestroyWindow(dpy, ww);

                XCloseDisplay(dpy);

                return prt;
            }
        }
    }

    public
    {
        RCIAllocator allocator;
        nvmlDevice_t handle;
        QueueFamilyProperties[] fprops;

        this(nvmlDevice_t handle, RCIAllocator allocator) @trusted
        {
            this.allocator = allocator;
            this.handle = handle;

            import core.cpuid;
            immutable tpc = threadsPerCPU();

            auto gprops = QueueFamilyProperties(QueueFlag.graphicsBit | QueueFlag.presentBit, tpc);
            auto cprops = QueueFamilyProperties(QueueFlag.computeBit, tpc); 
            auto tprops = QueueFamilyProperties(QueueFlag.transferBit, tpc);

            fprops = [gprops, cprops, tprops];
        }

        this(RCIAllocator allocator)
        {
            this(null, allocator);
        }

        version(Windows)
        this(DISPLAY_DEVICE dev, RCIAllocator allocator) @trusted
        {
            this(null, allocator);
            this.dev = dev;
        }

        version(Windows)
        this(__gapi_gl_dinfo dinfo, RCIAllocator allocator) @trusted
        {
            this(null, allocator);
            this.dinfo = dinfo;
        }

        PhysDeviceProperties getProperties()
        {
            version(Posix)
                return getPropertiesPosixImpl();

            version(Windows)
                return getPropertiesWinImpl();
        }

        string[] extensions()
        {
            return [];
        }
    }

    QueueFamilyProperties[] getQueueFamilyProperties()
    {
        return fprops.dup;
    }
}

extern(C) void __glLog(
    GLenum source,
    GLenum type,
    GLuint id,
    GLenum severity,
    GLsizei length,
    const(char*) message,
    const(void*) userParam
)
{
    import std.conv : to;
    import std.stdio;
    import gapi.extensions.backendnative;

    if (userParam is null)
        return;

    NativeLoggingInfo* nlgInfo = cast(NativeLoggingInfo*) userParam;
    if (!nlgInfo.hasLogging)
        return;

    string sourceID;
    string typeID;
    uint typeLog = 0;

    switch (source)
    {
        case GL_DEBUG_SOURCE_API:
            sourceID = "API";
        break;

        case GL_DEBUG_SOURCE_APPLICATION:
            sourceID = "Application";
        break;

        case GL_DEBUG_SOURCE_SHADER_COMPILER:
            sourceID = "Shader Program";
        break;

        case GL_DEBUG_SOURCE_WINDOW_SYSTEM:
            sourceID = "Window system";
        break;

        case GL_DEBUG_SOURCE_THIRD_PARTY:
            sourceID = "Third party";
        break;

        default:
            sourceID = "Unknown";
    }

    switch(type)
    {
        case GL_DEBUG_TYPE_ERROR:
            typeID = "Error";
            typeLog = 1;
            nlgInfo.logger.error("[OpenGL][", sourceID, "](", id, ") ", message.to!string);
        break;

        case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR:
            typeID = "Deprecated";
            typeLog = 2;
            nlgInfo.logger.warning("[OpenGL][", sourceID, "](", id, ") ", message.to!string);
        break;

        case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:
            typeID = "Undefined behaviour";
            typeLog = 3;
            nlgInfo.logger.critical("[OpenGL][", sourceID, "](", id, ") ", message.to!string);
        break;

        default:
            typeID = "Other";
            return;
    }

    
}

enum __gapi_gl_dev_type
{
    integrated_intel,
    discrete_nvidia, // NOTE: multi gpus not support
    integrated_amd, // maybe not support
    discrete_amd, // maybe not support
    discrete_intel // mayby not support
}

struct __gapi_gl_dinfo
{
    public
    {
        __gapi_gl_dev_type type;
    }
}

final class GLInstance : Instance
{
    RCIAllocator allocator;
    bool nvmlAvalible = false;

    private
    {
        version(Posix)
        {
            void posixLoadImpl() @trusted
            {
                dglx.glx.loadGLXLibrary();
                if (!loadNVML())
                {
                    nvmlAvalible = false;
                } else
                {
                    nvmlAvalible = true;
                    nvmlInit_v2();
                }
            }

            PhysDevice[] posixEnumImpl() @trusted
            {
                import std.conv : to;

                if (nvmlAvalible)
                {
                    uint cc;
                    nvmlDeviceGetCount_v2(&cc);

                    PhysDevice[] pds;
                    foreach (i; 0 .. cc)
                    {
                        nvmlDevice_t dev;
                        nvmlDeviceGetHandleByIndex_v2(i, &dev);

                        pds ~= make!(GLPhysDevice)(allocator, dev, allocator);
                    }

                    return pds;
                } else
                {
                    // AMD not support, but... Only intel.
                    return [make!(GLPhysDevice)(allocator, null, allocator)];
                }
            }
        }

        version(Windows)
        {
            void winLoadImpl() @trusted
            {
                // loadNVML();
                // nvmlInit_v2();
            }

            PhysDevice[] winEnumImpl() @trusted
            {
                import std.file : exists;

                if (loadNVML())
                {
                    GLPhysDevice ph = new GLPhysDevice(
                        __gapi_gl_dinfo(__gapi_gl_dev_type.discrete_nvidia),
                        allocator
                    );

                    return [ph];
                } else
                {
                    GLPhysDevice ph = new GLPhysDevice(
                        __gapi_gl_dinfo(__gapi_gl_dev_type.integrated_intel),
                        allocator
                    );

                    return [ph];
                }
            }
        }
    }

    public
    {
        ValidationLayer[] layers;

        this(RCIAllocator allocator, immutable CreateInstanceInfo icInfo) @trusted
        {
            this.allocator = allocator;

            version(Posix) 
            {
                posixLoadImpl();
            }

            version(Windows)
            {
                winLoadImpl();
            }

            layers = [
                ValidationLayer(
                    "GAPIDebugUtilMessenger",
                    false
                ),
                ValidationLayer(
                    "GPUNativeBackendUtilMessenger",
                    false
                ),
                ValidationLayer(
                    "GAPIErrorHandle",
                    false
                ),
                ValidationLayer(
                    "GAPIInputValidate",
                    false
                )
            ];

            foreach (e; icInfo.extensions)
            {
                switch (e)
                {
                    version(Posix)
                    {
                        case "GAPIPosixX11WindowInfo":
                        {
                            import gapi.extensions.pxx11;
                            import gapi.gl.extensions.pxx11;

                            createSurfaceFromWindow = (Instance instance, PosixX11WindowInfo windowInfo)
                            {
                                GLInstance glinstance = cast(GLInstance) instance;
                                GLPosixX11Surface surface = make!(GLPosixX11Surface)(glinstance.allocator, windowInfo, glinstance.allocator);

                                return surface;
                            };
                        }
                        break;
                    }
                    
                    version(Windows)
                    {
                        case "GAPIWin32WindowInfo":
                        {
                            import gapi.extensions.win32wi;
                            import gapi.gl.extensions.win32wi;

                            createSurfaceFromWindow = (Instance instance, Win32WindowInfo windowInfo)
                            {
                                GLInstance glinstance = cast(GLInstance) instance;
                                GLWin32Surface surface = make!(GLWin32Surface)(glinstance.allocator, windowInfo, glinstance.allocator);

                                return surface;
                            };
                        }
                        break;
                    }

                    case "GAPISDLWindowInfo":
                    {
                        import gapi.extensions.sdlsurface;
                        import gapi.gl.extensions.sdlsurface;

                        createSurfaceFromWindow = &SDL_CreateGAPISurface;
                    }
                    break;

                    case "GAPIVideoDecode":
                    {
                        import gapi.extensions.videodecode;
                        import gapi.gl.extensions.videodecode;

                        videoDecodeInit();
                    }
                    break;

                    default:
                    {
                        // warning
                    }
                    break;
                }
            }
        }

        string[] getExtensions() @trusted
        {
            string[] extensions;
            version(Windows)
            {
                extensions ~= ["GAPIWin32WindowInfo"];
            }

            version(Posix)
            {
                extensions ~= ["GAPIPosixX11WindowInfo"];
            }

            extensions ~= ["GAPISDLWindowInfo"];
            extensions ~= ["GAPIVideoDecode"];

            return extensions;
        }

        PhysDevice[] enumeratePhysicalDevices()
        {
            version(Posix)
                return posixEnumImpl();

            version(Windows)
                return winEnumImpl();
        }

        Device createDevice(PhysDevice pdevice, DeviceCreateInfo createInfo)
        {
            GLPhysDevice glpdevice = cast(GLPhysDevice) pdevice;

            return make!(GLDevice)(allocator, glpdevice, createInfo.queueCreateInfos, createInfo.validationLayers, allocator);
        }

        ValidationLayer[] enumerateValidationLayers()
        {
            return this.layers;
        }
    }
}

void glCreateInstance (
    immutable CreateInstanceInfo createInfo,
    RCIAllocator allocator,
    ref Instance instance
) @trusted
{
    instance = make!(GLInstance)(allocator, allocator, createInfo);
}
