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

final class GLBuffer : Buffer
{
    public
    {
        uint id;
        BufferUsage type;
        bool hasMap = false;

        this(BufferUsage type)
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

        void alloc(size_t size)
        {
            glNamedBufferData(id, cast(GLsizeiptr) size, null, GL_STATIC_DRAW);
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

final class GLImage : Image
{
    uint id;
    uint width_;
    uint height_;
    uint depth_;
    uint iformat;

    this(shared CmdCreateImage imgCrt)
    {
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
    import std.experimental.logger;
    
    import gapi.extensions.utilmessenger;
    import gapi.extensions.backendnative;
    import gapi.extensions.errhandle;

    private
    {
        QueueCreateInfo[] qCreateInfos;
        GLQueue[] queues;
        RCIAllocator allocator;
        LoggingDeviceInfo lgInfo;
        NativeLoggingInfo nlgInfo;
        ErrorLayerInfo errInfo;
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
                        if (e.initData.length != LoggingDeviceInfo.sizeof)
                            continue;

                        lgInfo = *(cast(LoggingDeviceInfo*) e.initData.ptr);
                        lgInfo.logger.info("Logger has connected!");
                    }
                    break;

                    case "GPUNativeBackendUtilMessenger":
                    {
                        if (e.initData.length != NativeLoggingInfo.sizeof)
                            continue;

                        nlgInfo = *(cast(NativeLoggingInfo*) e.initData.ptr);
                        nlgInfo.logger.info("Native logger has connected!");
                    }
                    break;

                    case "GAPIErrorHandle":
                    {
                        if (e.initData.length != ErrorLayerInfo.sizeof)
                            continue;

                        errInfo = *(cast(ErrorLayerInfo*) e.initData.ptr);
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
            shared Command command
        )
        {
            debug
            {
                throw new Exception("ATAAAS!", command.file, command.line);
            } else
            {
                throw new Exception("ATAAAS!");
            }
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

        void handleQueues_modern(ref GLQueue q)
        {
            import core.atomic;

            foreach (ref pl; q.pl)
            {
                handlePool_modern(cast(shared) q, cast(shared) pl);
            }

            q.hasExecute = true;
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

            if ((q.flag & pl.cmdFlag) != pl.cmdFlag)
                return;

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
                        GLSwapChain sc = cast(GLSwapChain) e.presentInfo.swapChain;
                        sc.swapBuffers(e.presentInfo);
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

                        if (bf.type != BufferUsage.renderbuffer)
                            continue;

                        glNamedFramebufferRenderbuffer(fb.id, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, bf.id);
                    }
                    break;

                    case CommandType.clearFrameBuffer:
                    {
                        GLFrameBuffer fb = cast(GLFrameBuffer) e.clearFrameBufferInfo.frameBuffer;
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
                        *e.createPipelineInfo.pipeline = cast(shared) make!(GLPipeline)(allocator, e.createPipelineInfo, allocator);
                    }
                    break;

                    case CommandType.allocBuffer:
                    {
                        GLBuffer buffer = cast(GLBuffer) e.allocBufferInfo.buffer;
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

                        glClearNamedFramebufferfv(rpb_fb.id, GL_COLOR, 0, cast(float*) e.renderPassBegin.clearColor.ptr);
                    }
                    break;

                    case CommandType.createImage:
                    {
                        GLImage img = make!(GLImage)(allocator, e.createImageInfo);
                        *e.createImageInfo.image = cast(shared Image) img;
                    }
                    break;

                    case CommandType.bindImageMemory:
                    {
                        // CmdBindImageMemory
                        GLImage img = cast(GLImage) e.bindImageMemoryInfo.image;
                        if (e.bindImageMemoryInfo.length + e.bindImageMemoryInfo.offset > e.bindImageMemoryInfo.data.length)
                        {
                            immutable message = "The size in the arguments is larger than the array itself.";
                            if (lgInfo.hasLogging && lgInfo.logger !is null)
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
                    break;

                    case CommandType.createSampler:
                    {
                        GLSampler smp = make!(GLSampler)(allocator, e.createSamplerInfo);
                        *e.createSamplerInfo.sampler = cast(shared Sampler) smp;
                    }
                    break;

                    case CommandType.editSampler:
                    {
                        GLSampler smp = cast(GLSampler) e.editSamplerInfo.sampler;
                        smp.edit(e.editSamplerInfo);
                    }
                    break;

                    case CommandType.draw:
                    {
                        GLPipeline pp = cast(GLPipeline) e.drawInfo.pipeline;
                        GLBuffer vb = cast(GLBuffer) e.drawInfo.vertexBuffer;

                        glEnable(GL_SCISSOR_TEST);

                        auto vv = pp.pipelineInfo.viewportState.viewport;
                        auto sc = pp.pipelineInfo.viewportState.scissor;
                        glViewport(cast(int) vv.x, cast(int) vv.y, cast(int) vv.width, cast(int) vv.height);
                        glScissor(cast(int) sc.offset[0], cast(int) sc.offset[1], cast(int) sc.extent[0], cast(int) sc.extent[1]);

                        if (pp.pipelineInfo.rasterization.depthClampEnable)
                            glEnable(GL_DEPTH_CLAMP);

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

                        foreach (ef; pp.pipelineInfo.writeDescriptions)
                        {
                            if (ef.type == WriteDescriptType.uniform)
                            {
                                size_t it = 0;
                                foreach (md; pp.pipelineInfo.stages)
                                {
                                    if ((ef.uniform.stageFlags & md.stage) == md.stage)
                                    {
                                        immutable eg = pp.stages[it];
                                        GLBuffer bg = cast(GLBuffer) ef.uniform.buffer;

                                        glUniformBlockBinding(eg.pid, ef.binding, ef.binding);

                                        glBindBufferRange(
                                            GL_UNIFORM_BUFFER,
                                            ef.binding,
                                            bg.id,
                                            cast(GLintptr) ef.uniform.offset,
                                            cast(GLsizeiptr) ef.uniform.size
                                        );
                                    }

                                    it++;
                                }
                            } else
                            if (ef.type == WriteDescriptType.imageSampler)
                            {
                                if (ef.imageView.sampler is null)
                                {
                                    // if (pl.errorState !is null)
                                    // {
                                    //     pl.errorState.commandType = e.type;
                                    //     pl.errorState.what = "The sampler object is empty.";
                                    //     pl.errorState.code = 1;
                                    // }
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
            WGL_CONTEXT_MINOR_VERSION_ARB, 5,
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
                WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
                WGL_CONTEXT_MINOR_VERSION_ARB, 3,
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

                uint dims;
                glGetIntegerv(GL_MAX_FRAMEBUFFER_WIDTH, cast(int*) &dims);
                prt.limits.maxFramebufferWidth = dims;
                glGetIntegerv(GL_MAX_FRAMEBUFFER_HEIGHT, cast(int*) &dims);

                prt.limits.maxFramebufferHeight = dims;
                dims = 0;

                glGetIntegerv(GL_MAX_FRAMEBUFFER_LAYERS, cast(int*) &dims);
                prt.limits.maxFramebufferLayers = dims;

                glGetIntegerv(GL_MAX_SAMPLES, cast(int*) &dims);
                prt.limits.sampleCounts = dims;

                glGetIntegerv(GL_MAX_TEXTURE_SIZE, cast(int*) &prt.limits.maxTextureSize);
                glGetIntegerv(GL_MAX_VERTEX_ATTRIBS, cast(int*) &prt.limits.maxVertexInputAttribs);
                glGetIntegerv(GL_MAX_VERTEX_OUTPUT_COMPONENTS, cast(int*) &prt.limits.maxVertexOutputComponents);
                glGetIntegerv(GL_MAX_GEOMETRY_INPUT_COMPONENTS, cast(int*) &prt.limits.maxGeometryInputComponents);
                glGetIntegerv(GL_MAX_GEOMETRY_OUTPUT_COMPONENTS, cast(int*) &prt.limits.maxGeometryOutputComponents);
                glGetIntegerv(GL_MAX_FRAGMENT_INPUT_COMPONENTS, cast(int*) &prt.limits.maxFragmentInputComponents);
                glGetIntegerv(GL_MAX_VERTEX_UNIFORM_BLOCKS, cast(int*) &prt.limits.maxVertexUniformBlocks);
                glGetIntegerv(GL_MAX_FRAGMENT_UNIFORM_BLOCKS, cast(int*) &prt.limits.maxFragmentUniformBlocks);
                prt.limits.maxFragmentOutputComponents = 4;



                char* cattribs;
                if ((cattribs = cast(char*) glGetString(GL_EXTENSIONS)) is null)
                {
                    throw new UnsupportException(UnsupportType.interfaceBroken);
                }
                
                string[] attribs = cstrlist(cattribs);

                foreach (attrib; attribs)
                {
                    switch (attrib)
                    {
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

                        default:
                            break;
                    }
                }

                return prt;
            }
        }

        version(Posix)
        {
            Display* dpy;

            PhysDeviceProperties getPropertiesPosixImpl() @trusted
            {
                import bindbc.opengl;
                import std.conv : to;

                dpy = XOpenDisplay(null);

                PhysDeviceProperties prt;
                char[] name = makeArray!(char)(allocator, 80);

                nvmlDeviceGetName(handle, name.ptr, 80);
                prt.deviceName = name.to!(string);

                nvmlPciInfo_t pinfo;
                nvmlDeviceGetPciInfo_v3(handle, &pinfo);
                prt.deviceID = pinfo.pciDeviceId;

                nvmlSystemGetDriverVersion(name.ptr, 80);
                prt.driverVersion = name.to!(string);

                allocator.deallocate(cast(void[]) name);

                prt.vendor = glXGetClientString(dpy, 1).to!string;

                uint count;
                nvmlVgpuTypeId_t[5] tts;

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

                prt.type = PhysDeviceType.discrete;
                prt.limits = limits;

                Window ww = XCreateSimpleWindow(dpy, RootWindow(dpy, 0),
                    0, 0, 32, 32, 0, 0, 0);
                auto ctx = glXCreateNewContext(dpy, cfgs[maxID], GLX_RGBA_TYPE, null, true);
                glXMakeCurrent(dpy, ww, ctx);

                loadOpenGL();

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

                string[] attribs = cstrlist(glGetString(GL_EXTENSIONS));

                foreach (attrib; attribs)
                {
                    switch (attrib)
                    {
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

                        default:
                            break;
                    }
                }

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

final class GLSwapChain : SwapChain
{
    private
    {
        version(Posix)
        {
            Display* dpy;
            GLXPixmap gpixmap;
            Pixmap pixmap;
            GLXContext context;
            GC gc;
            Window* wnd;

            void swapBuffersPosixImpl() @trusted
            {
                glXSwapBuffers(dpy, *wnd);
            }
        }

        version(Windows)
        {
            HMODULE hInstance;
            HDC dc;

            void swapBuffersWinImpl() @trusted
            {
                SwapBuffers(dc);
            }
        }
    }

    public
    {
        RCIAllocator allocator;

        uint[2] extend;
    }

    public
    {
        version(Posix)
        this(
            Display* dpy,
            GLSurface surface,
            GLDevice gdevice,
            CreateSwapChainInfo createInfo,
            RCIAllocator allocator)
        {
            this.dpy = dpy;
            this.wnd = surface.drawable;
            this.allocator = allocator;

            int fbcount = 0;
            scope fbc = glXGetFBConfigs(dpy, 0, &fbcount); scope(exit) XFree(fbc);

            if (fbcount == 0)
            {
                throw new Exception("Your system not enought fb configs");
            }

            GLXFBConfig cfg;

            foreach (i; 0 .. fbcount)
            {
                int drw,
                    rdtype,
                    vstype,
                    rs, gs, bs, as,
                    ds, ss,
                    db,
                    sp;

                glXGetFBConfigAttrib(dpy, fbc[i], GLX_DRAWABLE_TYPE, &drw);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_RENDER_TYPE, &rdtype);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_X_VISUAL_TYPE, &rdtype);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_RED_SIZE, &rs);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_GREEN_SIZE, &gs);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_BLUE_SIZE, &bs);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_ALPHA_SIZE, &as);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_DEPTH_SIZE, &ds);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_STENCIL_SIZE, &ss);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_DOUBLEBUFFER, &db);
                glXGetFBConfigAttrib(dpy, fbc[i], GLX_SAMPLES, &sp);

                if ((drw & GLX_WINDOW_BIT) == GLX_WINDOW_BIT &&
                    (rdtype & GLX_RGBA_BIT) == GLX_RGBA_BIT &&
                    rs == createInfo.format.redSize &&
                    gs == createInfo.format.greenSize &&
                    bs == createInfo.format.blueSize &&
                    as == createInfo.format.alphaSize &&
                    ds == createInfo.format.depthSize &&
                    ss == createInfo.format.stencilSize &&
                    sp == createInfo.format.sampleCount &&
                    db == (createInfo.presentMode != PresentMode.immediate)
                    )
                {
                    cfg = fbc[i];
                    break;
                }
            }

            if (cfg is null)
                throw new Exception("Not absolute config!");

            XVisualInfo* vinfo = glXGetVisualFromFBConfig(dpy, cfg);

            int[5] ctxAttrib = [
                GLX_CONTEXT_MAJOR_VERSION_ARB, 4,
                GLX_CONTEXT_MINOR_VERSION_ARB, 6,
                None
            ];

            context = glXCreateContextAttribsARB(
                dpy,
                cfg,
                null,
                true,
                ctxAttrib.ptr
            );

            XWindowAttributes wattribs;
            XGetWindowAttributes(dpy, *wnd, &wattribs);

            XDestroyWindow(dpy, *wnd);

            XSetWindowAttributes windowAttribs;
            windowAttribs.border_pixel = 0x000000;
            windowAttribs.background_pixel = 0xFFFFFF;
            windowAttribs.override_redirect = wattribs.override_redirect;
            windowAttribs.colormap = XCreateColormap(dpy, RootWindow(dpy, 0),
                                                     vinfo.visual, AllocNone);
            windowAttribs.event_mask = wattribs.your_event_mask;

            *wnd = XCreateWindow (
                dpy, RootWindow(dpy, 0),
                wattribs.x, wattribs.y,
                wattribs.width, wattribs.height,
                0,
                vinfo.depth,
                InputOutput,
                vinfo.visual,
                CWBackPixel | CWColormap | CWBorderPixel | CWEventMask,
                &windowAttribs
            );
            XMapWindow(dpy, *wnd);

            glXMakeCurrent(dpy, *wnd, context);

            loadOpenGL();

            glEnable(GL_DEBUG_OUTPUT);
            glDebugMessageCallback(cast(GLDEBUGPROC) &__glLog, cast(void*) &gdevice.nlgInfo);
        }

        version(Windows)
        this(
            GLSurface surface,
            GLDevice gdevice,
            CreateSwapChainInfo createInfo,
            RCIAllocator allocator
        )
        {
            hInstance = surface.hInstance;

            auto deviceHandle = GetDC(surface.wnd);

            immutable colorBits =   createInfo.format.redSize + 
                                    createInfo.format.greenSize +
                                    createInfo.format.blueSize +
                                    createInfo.format.alphaSize;

            immutable pfdFlags = createInfo.presentMode == PresentMode.immediate ?
                (PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL) :
                (PFD_DOUBLEBUFFER | PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL);

            PIXELFORMATDESCRIPTOR pfd;
            pfd.nSize = PIXELFORMATDESCRIPTOR.sizeof;
            pfd.nVersion = 1;
            pfd.dwFlags = pfdFlags;
            pfd.iPixelType = PFD_TYPE_RGBA;
            pfd.cRedBits = cast(ubyte) createInfo.format.redSize;
            pfd.cGreenBits = cast(ubyte) createInfo.format.greenSize;
            pfd.cBlueBits = cast(ubyte) createInfo.format.blueSize;
            pfd.cAlphaBits = cast(ubyte) createInfo.format.alphaSize;
            pfd.cDepthBits = cast(ubyte) createInfo.format.depthSize;
            pfd.cStencilBits = cast(ubyte) createInfo.format.stencilSize;
            pfd.cColorBits = cast(ubyte) colorBits;
            pfd.iLayerType = PFD_MAIN_PLANE;

            auto chsPixel = ChoosePixelFormat(deviceHandle, &pfd);
            if (chsPixel == 0)
            {
                import std.conv : to;
                LPSTR messageBuffer = null;

                size_t size = FormatMessageA(
                    FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                    null, 
                    cast(uint) GetLastError(), 
                    MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US), 
                    cast(LPSTR) &messageBuffer, 
                    0, 
                    null
                );
                throw new UnsupportException(messageBuffer.to!string);
            }

            if (!SetPixelFormat(deviceHandle, chsPixel, &pfd))
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }

            auto ctx = wglCreateContext(deviceHandle);
            if (!wglMakeCurrent(deviceHandle, ctx))
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }

            initWGL();

            int[] iattrib =  
            [
                WGL_SUPPORT_OPENGL_ARB, true,
                WGL_DRAW_TO_WINDOW_ARB, true,
                WGL_DOUBLE_BUFFER_ARB, createInfo.presentMode == PresentMode.immediate ? false : true,
                WGL_RED_BITS_ARB, createInfo.format.redSize,
                WGL_GREEN_BITS_ARB, createInfo.format.greenSize,
                WGL_BLUE_BITS_ARB, createInfo.format.blueSize,
                WGL_ALPHA_BITS_ARB, createInfo.format.alphaSize,
                WGL_DEPTH_BITS_ARB, createInfo.format.depthSize,
                WGL_COLOR_BITS_ARB, colorBits,
                WGL_STENCIL_BITS_ARB, createInfo.format.stencilSize,
                WGL_PIXEL_TYPE_ARB, WGL_TYPE_RGBA_ARB,
                0
            ];

            uint nNumFormats;
            int[20] nPixelFormat;
            wglChoosePixelFormatARB(
                deviceHandle,   
                iattrib.ptr, 
                null,
                20, nPixelFormat.ptr,
                &nNumFormats
            );

            bool isSuccess = false;
            foreach (i; 0 .. nNumFormats)
            {
                DescribePixelFormat(deviceHandle, nPixelFormat[i], pfd.sizeof, &pfd);
                if (SetPixelFormat(deviceHandle, nPixelFormat[i], &pfd) == true)
                {
                    isSuccess = true;
                    break;
                }
            }

            if (!isSuccess)
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }

            // Use deprecated functional
            int[] attrib =  
            [
                WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
                WGL_CONTEXT_MINOR_VERSION_ARB, 5,
                WGL_CONTEXT_FLAGS_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                0
            ];

            auto mctx = wglCreateContextAttribsARB(     deviceHandle, 
                                                        null, 
                                                        attrib.ptr);
            if (mctx is null)
            {
                attrib =  
                [
                    WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
                    WGL_CONTEXT_MINOR_VERSION_ARB, 3,
                    WGL_CONTEXT_FLAGS_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                    WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
                    0
                ];

                mctx = wglCreateContextAttribsARB(      deviceHandle, 
                                                        null, 
                                                        attrib.ptr);

                if (mctx is null)
                {
                    throw new UnsupportException(UnsupportType.interfaceOutdated);
                }
            }

            wglMakeCurrent(null, null);
            wglDeleteContext(ctx);

            if (!wglMakeCurrent(deviceHandle, mctx))
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }

            if (loadOpenGL() < GLSupport.gl45)
            {
                throw new UnsupportException(UnsupportType.interfaceOutdated);
            }

            this.dc = deviceHandle;

            glEnable(GL_DEBUG_OUTPUT);
            glDebugMessageCallback(cast(GLDEBUGPROC) &__glLog, &gdevice.nlgInfo);
        }

        void swapBuffers(shared CmdPresentInfo info)
        {
            version(Posix)
                swapBuffersPosixImpl();

            version(Windows)
                swapBuffersWinImpl();
        }
    }
}

final class GLSurface : Surface
{
    private
    {
        version(Posix)
        {
            Display* dpy;
            Window* drawable;
            GLXContext context;

            void posixInit(CreateSurfaceInfo createInfo) @trusted
            {
                this.dpy = cast(Display*) createInfo.windowInfo.dpy;
                this.drawable = createInfo.wnd;

                int fbclen;
                GLXFBConfig* fbcs = glXGetFBConfigs(dpy, 0, &fbclen);
                scope(exit) XFree(fbcs);

                formats = makeArray!(SurfaceFormat)(allocator, fbclen);

                foreach (i; 0 .. fbclen)
                {
                    auto fbc = fbcs[i];

                    Format fmt;
                    glXGetFBConfigAttrib(dpy, fbc, GLX_RED_SIZE, cast(int*) &fmt.redSize);
                    glXGetFBConfigAttrib(dpy, fbc, GLX_GREEN_SIZE, cast(int*) &fmt.greenSize);
                    glXGetFBConfigAttrib(dpy, fbc, GLX_BLUE_SIZE, cast(int*) &fmt.blueSize);
                    glXGetFBConfigAttrib(dpy, fbc, GLX_ALPHA_SIZE, cast(int*) &fmt.alphaSize);
                    glXGetFBConfigAttrib(dpy, fbc, GLX_DEPTH_SIZE, cast(int*) &fmt.depthSize);
                    glXGetFBConfigAttrib(dpy, fbc, GLX_STENCIL_SIZE, cast(int*) &fmt.stencilSize);

                    PresentMode pmode;
                    int bmode;
                    glXGetFBConfigAttrib(dpy, fbc, GLX_DOUBLEBUFFER, &bmode);

                    if (bmode)
                        pmode = PresentMode.fifo;
                    else
                        pmode = PresentMode.immediate;

                    formats[i] = SurfaceFormat(fmt, pmode);
                }
            }
        }

        version(Windows)
        {
            HMODULE hInstance;
            HWND wnd;

            void win32Init(CreateSurfaceInfo createInfo) @trusted
            {
                if (!IsWindow(*createInfo.windowInfo.wnd))
                {
                    throw new InvalidWindow(createInfo);
                }

                auto info = __gapi_init_wgl();

                uint nums = 0;
                wglGetPixelFormatAttribivARB(
                    info.dc,
                    0,
                    0,
                    1,
                    [WGL_NUMBER_PIXEL_FORMATS_ARB].ptr,
                    cast(int*) &nums
                );

                formats = makeArray!(SurfaceFormat)(allocator, nums);
                foreach (i; 1 .. nums)
                {
                    Format format;
                    wglGetPixelFormatAttribivARB(
                        info.dc,
                        i,
                        0,
                        6,
                        [
                            WGL_RED_BITS_ARB,
                            WGL_GREEN_BITS_ARB,
                            WGL_BLUE_BITS_ARB,
                            WGL_ALPHA_BITS_ARB,
                            WGL_DEPTH_BITS_ARB,
                            WGL_STENCIL_BITS_ARB,
                        ].ptr,
                        cast(int*) &format
                    );

                    PresentMode mode;
                    uint md;
                    wglGetPixelFormatAttribivARB(
                        info.dc,
                        i,
                        0,
                        1,
                        [
                            WGL_DOUBLE_BUFFER_ARB
                        ].ptr,
                        cast(int*) &md
                    );
                    mode = md == 1 ? PresentMode.fifo : PresentMode.immediate;

                    formats[i - 1] = SurfaceFormat(format, mode);
                }

                __gapi_dst_twnd(info);

                this.hInstance = createInfo.windowInfo.hInstance;
                this.wnd = *createInfo.windowInfo.wnd;
            }
        }
    }

    public
    {
        
        RCIAllocator allocator;
        SurfaceFormat[] formats;
    }

    public
    {
        this(CreateSurfaceInfo createInfo, RCIAllocator allocator)
        {
            this.allocator = allocator;
            version(Posix)
                posixInit(createInfo);

            version(Windows)
                win32Init(createInfo);
        }

        SurfaceFormat[] getFormats()
        {
            return this.formats;
        }

        SwapChain createSwapChain(Device device, CreateSwapChainInfo createInfo)
        {
            GLDevice gdevice = cast(GLDevice) device;

            GLSwapChain sc;

            version(Posix)
                sc = make!(GLSwapChain)(allocator, dpy, this, gdevice, createInfo, allocator);

            version(Windows)
                sc = make!(GLSwapChain)(allocator, this, gdevice, createInfo, allocator);

            return sc;
        }

        ~this()
        {
            dispose(allocator, formats);
        }
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

    private
    {
        version(Posix)
        {
            void posixLoadImpl() @trusted
            {
                dglx.glx.loadGLXLibrary();
                loadNVML();
                nvmlInit_v2();
            }

            PhysDevice[] posixEnumImpl() @trusted
            {
                import std.conv : to;

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

                //return null;
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
                )
            ];
        }

        string[] getExtensions() @trusted
        {
            return [];
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

        Surface createSurface(CreateSurfaceInfo createInfo)
        {
            GLSurface gsurface = make!(GLSurface)(allocator, createInfo, allocator);

            return gsurface;
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
