module gapi;

public import gapi.exception;
public import std.experimental.allocator;

/++
Информация о приложении, которая взаимодействует с графической API.
+/
struct ApplicationInfo
{
    public
    {
        /// Название приложении.
        string applicationName;
        
        /// Версия приложения.
        uint applicationVersion;

        /// Название движка, на котором работает приложении.
        string engineName;
        
        /// Версия движка, на котором работает приложение.
        uint engineVersion;
    }
}

/++
Лимиты устройства.
Максимальные значения использования тех или иных технологий.
+/
struct PhysDeviceLimits
{
    public
    {
        /// Максимальный размер текстуры. Сторона выбирается от размера такой
        /// стороны.
        uint maxTextureSize;
        
        /// Максимальный размер буфера кадра по ширине.
        uint maxFramebufferWidth;
        
        /// Максимальный размер буфера кадра по высоте.
        uint maxFramebufferHeight;
        
        /// Максимальное количество слоев кадра.
        uint maxFramebufferLayers;

        /// Максимальное количество входных вершинных аттрибутов в шейдере.
        uint maxVertexInputAttribs;
        
        /// Максимальное количество выходных компонентов в шейдере.
        uint maxVertexOutputComponents;

        /// Максимальное количество блоков юниформ в вершинном шейдере.
        uint maxVertexUniformBlocks;

        /// Максимальное количество входных компонентов в геометрическом шейдере.
        uint maxGeometryInputComponents;
        
        /// Максимальное количество выходных компонентов в геометрическом шейдере.
        uint maxGeometryOutputComponents;

        /// Максимальное количество входных компонентов в фрагментном шейдере.
        uint maxFragmentInputComponents;
        
        /// Максимальное количество выходных компонентов в фрагментом шейдере.
        uint maxFragmentOutputComponents;

        /// Максимальное количество блоков юниформ в геометрическом шейдере.
        uint maxFragmentUniformBlocks;

        /// TODO: как нить потом прокоментирую
        uint sampleCounts;

        uint maxComputeSharedMemorySize;

        uint[3] maxComputeWorkGroupCount;

        uint maxComputeWorkGroupInvocations;

        uint[3] maxComputeWorkGroupSize;

        uint subPixelPrecisionBits;

        uint maxViewports;
    }
}

/++
Структура доступных технологий для использования.

Описывают, какие технологии доступны для использования. Обратите внимание,
что те технологии, что не доступны, не ломают всю систему. Однако, это
относится только к некоторым технологиям, которые не особо нужны для
использования.
+/
struct PhysDeviceFeatures
{
    public
    {
        /// Поддержка теста scissor.
        bool scissor;

        /// Поддержка геометрический шейдеров.
        bool geometryShader;
        
        /// Поддержка шейдеров тесселяции.
        bool tessellationShader;
        
        /// Поддержка одновременной отрисовки нескольких объектов.
        bool multiDrawIndirect;
        
        /// Поддержка нескольких видимых портов.
        bool multiViewport;
        
        /// Поддержка загрузки и использования сжатых текстур.
        bool textureCompression;
        
        /// ditto
        bool textureCompressionBPCT;
        
        /// ditto
        bool textureCompressionRGTC;
        
        /// Поддержка 64-ых битных целочисленных переменных в шейдерах.
        bool shaderInt64;
        
        /// Поддержка 64-ых битных чисел с плавающей точной переменных в шейдерах.
        bool shaderFloat64;
        
        /// 
        bool shaderClipDistance;
        
        /// 
        bool shaderCullDistance;
        
        /// Поддержка загрузки в шейдер SPIR-V байт-кода.
        ///
        /// Стоит обратить внимание, что такая часть необходима, т.к.
        /// большинство функций ориентируются на него, однако, есть функции
        /// компиляции шейдеров в нативный код, однако, для него должна быть
        /// поддержка выдачи бинарного кода.
        bool spirv;
        
        /// Поддержка выдачи бинарного кода после процесса компиляции шейдера
        /// вендором.
        ///
        /// Такая поддержка подразумевает выдачу нативного кода для кешерирования
        /// шейдеров. Применима только к opengl/direct9-10 бекендам.
        bool cachedShaderBinary;
    }
}

/// Тип устройства.
enum PhysDeviceType
{
    /// Другие типы устройств.
    other,

    /// Интегрированные устройства.
    integrate,

    /// Дискретные устройства.
    discrete,

    /// Виртуальное устройство, выполняющее вычисления с помощью процессора.
    cpu,

    /// Устройство реализовано на собственном бекенде.
    nativeCPU
}

/++
Информация о девайсе.
+/
struct PhysDeviceProperties
{
    public
    {
        bool avalibleForCreation;

        /// Версия драйвера, исполняющая бекенд.
        ///
        /// Обратите внимание, указывается драйвер вендора видеокарты, а не
        /// графического доступа.
        string driverVersion;

        /// Наименование девайса.
        string deviceName;

        /// Номер девайса.
        uint deviceID;

        /// Наименование вендора устройства.
        string vendor;

        /// Тип девайса.
        ///
        /// other - Другие типы устройств.
        /// integrate - Интегрирированное устройство.
        /// discrete - Дискретное устройство.
        /// cpu - Виртуальное устройство на вычислениях процессора.
        PhysDeviceType type;

        /// Лимиты устройства.
        PhysDeviceLimits limits;

        /// Доступные технологии устройства.
        ///
        /// Обратите внимание, что это обычные распространённые технологии.
        /// Более едкие технологии выполняются через расширения.
        PhysDeviceFeatures features;
    }
}

/++
Типы функции очередей.
+/
enum QueueFlag
{
    /// Тип очереди на исполнение графических команд.
    graphicsBit,

    /// Тип очереди команд на отображение кадрового буфера в окно.
    presentBit,

    /// Тип очереди на исполнение вычислительных команд.
    computeBit,

    /// Тип очереди команд на исполнение операции с памятью.
    transferBit
}

/++
Свойства очередей.

Описываются возможностями устройства, сколько оно может обрабатывать очередей.
+/
struct QueueFamilyProperties
{
    public
    {
        /// Флаги функций очереди.
        QueueFlag queueFlags;

        /// Колличества создаваемых очередей.
        uint queueCount;
    }
}

/++
Объект описания физического устройства.

Из него можно вытянуть некоторую информацию, чтобы, например,
найти из других устройств самый лучший.
+/
interface PhysDevice
{
    public
    {
        /// Функция получений характеристик, лимитов и прочей информации о
        /// физическом устройстве.
        PhysDeviceProperties getProperties();

        string[] extensions();

        /// Функция выдаёт доступные под создание очереди.
        QueueFamilyProperties[] getQueueFamilyProperties();
    }
}

/++
Описание создаваемой очереди.

Необходим для создания очереди из дескриптора устройства.
+/
struct QueueCreateInfo
{
    public
    {
        /// Номер очереди. 
        ///
        /// Нужные номера можно посмотреть через функцию `getQueueFamilyProperties`
        /// у объекта PhysDevice.
        uint queueIndex;

        /// Колличество очередей.
        uint queueCount; 

        /// Приоритет очереди среди других.
        ///
        /// Это означает, что чем выше значение,
        /// тем раньше будет обработана очередь среди других.
        float priority;
    }
}

/++
Описание инициализации верифицированных структур.

Верифицированная структура - объект обработки отладочных данных, а также
для отловки и обработки ошибок при исполнении команд.
+/
struct ValidationLayerInfo
{
    import  gapi.extensions.backendnative;
    import  gapi.extensions.errhandle;
    import  gapi.extensions.inputvalidate;
    import  gapi.extensions.utilmessenger;

    public
    {
        /// Имя структуры, которую нужно инциализировать.
        string name;

        /// Состояние, нужно включать такую структуру в устройство.
        bool enabled = false;
        
        /// Передаваемые данные для инициализации структуры.
        union
        {
            NativeLoggingInfo nativeLoggingInfo;
            ErrorLayerInfo errorLayerInfo;
            InputValidationLayer inputValidationLayer;
            LoggingDeviceInfo loggingDeviceInfo;
        }
    }

    this(T)(string name, bool enabled, T initData)
    {
        this.name = name;
        this.enabled = enabled;
        
        static foreach (member; __traits(allMembers, typeof(this)))
        {
            static if (is(typeof(__traits(getMember, typeof(this), member)) == T))
            {
                __traits(getMember, typeof(this), member) = initData;
            }
        }
    }
}

/++
Описание создании дескриптора устройсва.

Дескриптор устройства отвечает за отправку команд для реального устройства.
+/
struct DeviceCreateInfo
{
    public
    {
        QueueCreateInfo[] queueCreateInfos;
        ValidationLayerInfo[] validationLayers;
    }
}

/// Типы команд исполнения для устройства.
enum CommandType
{
    /// Номер команды отравки кадра в окно.
    ///
    /// See_Also: CmdPresentInfo
    present,

    /// Номер команды создания кадрового буфера.
    ///
    /// See_Also: CmdCreateFrameBuffer
    createFrameBuffer,
    
    /// Номер команды создания буфера данных. 
    ///
    /// See_Also: : CmdCreateBuffer
    createBuffer,

    /// Номер команды выделения памяти под буфер для рендеринга.
    ///
    /// See_Also: CmdAllocRenderBuffer
    allocRenderBuffer,

    /// Номер команды выделения памяти под буфер дляразличных данных.
    ///
    /// See_Also: CmdAllocBuffer
    allocBuffer,

    /// Номер команды копирования данных между двумя буферами.
    ///
    /// See_Also: CmdCopyBuffer
    copyBuffer,

    /// Номер команды привязки буфера данных под кадровый буфер.
    ///
    /// See_Also: CmdFrameBufferBindBuffer
    frameBufferBindBuffer,

    /// Номер команды очищения кадрового буфера указанным цветом.
    ///
    /// See_Also: CmdClearFrameBuffer
    clearFrameBuffer,

    /// Номер команды копирования кадрового буфера под поверхность оконного буфера.
    ///
    /// See_Also: CmdBlitFrameBufferToSurface
    blitFrameBufferToSurface,

    /// Номер команды создания шейдерного модуля.
    ///
    /// See_Also: CmdCreateShaderModule
    createShaderModule,

    /// Номер команды уничтожения шейдерного модуля.
    ///
    /// See_Also: CmdDestroyShaderModule
    destroyShaderModule,

    /// Номер команды компилирования шейдерного кода.
    /// 
    /// See_Also: CmdCompileShaderModule
    compileShaderModule,

    /// Номер команды создания конвеера.
    ///
    /// See_Also: CmdCreatePipeline
    createPipeline,

    createComputePipeline,

    /// Номер команды отображения буфера в адресное пространство пользователя.
    ///
    /// See_Also: CmdMapBuffer
    mapBuffer,

    /// Номер команды снятия буфера с адресного пространства пользователя.
    ///
    /// See_Also: CmdUnmapBuffer
    unmapBuffer,

    /// Номер команды для изменения данных буфера.
    ///
    /// See_Also: CmdBuffSetData
    bufferSetData,

    /// Номер команды для начала шага рисования кадра.
    ///
    /// See_Also: CmdRenderPassInfo
    renderPassBegin,

    /// Номер команды рисования объекта в кадр.
    ///
    /// See_Also: CmdDraw
    draw,

    /// Номер команды для конца шага рисования кадра.
    renderPassEnd,

    /// Номер команды создания изображения.
    ///
    /// See_Also: CmdCreateImage
    createImage,

    /// Номер команды редактирования свойств изображения.
    ///
    /// See_Also: CmdEditImage
    editImage,

    /// Номер команды привязки данных изображения из пространства пользователя в пространство устройства.
    ///
    /// See_Also: CmdBindImageMemory
    bindImageMemory,

    /// Номер команды уничтожения изображения.
    ///
    /// See_Also: CmdDestroyImage
    destroyImage,

    /// Номер команды создания сэмплера.
    ///
    /// See_Also: CmdCreateSampler
    createSampler,

    /// Номер команды редактирования сэмплера.
    ///
    /// See_Also: CmdEditSampler
    editSampler,

    /// Номер команды уничтожения сэмплера.
    ///
    /// See_Also: CmdDestroySampler
    destroySampler,

    /// Номер команлы изменения динамичких свойств конвеера.
    ///
    /// See_Also: CmdPipelineEdit
    pipelineEdit,

    /// Номер команды уничтожения буфера данных.
    ///
    /// See_Also: CmdDestroyBuffer
    destroyBuffer,

    /// Номер команды уничтожения конвеера.
    ///
    /// See_Also: CmdDestroyPipeline
    destroyPipeline,

    /// Номер команды уничтожения кадрового буфера.
    ///
    /// See_Also: CmdDestroyFrameBuffer
    destroyFrameBuffer,

    createImageView,

    updateImageView,

    /// Команда, которая не входит в состав обычных команд
    ///
    /// See_Also: Device.extesions, CmdExt
    extensionCommand
}

/++
Команда отправки кадра в окно.

Именно, по спецификации, отправляется регион из кадра в окно.
Координаты, которые нужно указать, будут влиять как на выбор
региона из итогового кадра, так и на регион окна, куда будет
залит кадр.

Команда избавляет программиста от отвественности ручному передаче
изображений на перенос к окну, поэтому, достаточно просто указать
объект очереди (SwapChain).

Examples: 
---
cmdPool.commands = [
    Command(CommandType.present, CmdPresentInfo(
        swapChain, 0, 0, window_width, window_height
    ))
];
---
+/
struct CmdPresentInfo
{
    public
    {
        /// Объект очереди изображений. 
        SwapChain swapChain;

        /// Начало региона переноса по оси абцисс.
        int x = 0;

        /// Начало региона переноса по оси ординат. 
        int y = 0;

        /// Ширина региона переноса кадра.
        uint w = 0;

        /// Высота региона переноса кадра.
        uint h = 0;
    }
}

/++
Команда создания кадрового буфера.

Выделяет память только под десктриптор, память для кадра ещё
не будет выделен, это делается командой CmdAllocRenderBuffer
для отдельного буфера.
+/
struct CmdCreateFrameBuffer
{
    public
    {
        /// Указатель на дескриптор, куда будет передан объект.
        FrameBuffer* frameBuffer;
    }
}

/++
Описание способа использования буфера.

Т.е. это говорит устройству, как оптимизировать работу
под конкретные условия использования буфера.
+/
enum BufferUsage
{
    /// Использовать просто как массив данных.
    array,

    /// Использовать место для набора идентификаторов единицы вершины.
    element,

    /// Использовать место под кадр.
    renderbuffer,

    /// Использовать место для динамических данных шейдера.
    uniform
}

/++
Команда создания дескриптора буфера данных.

В аргументах обязательно нужно указать, под какой вид
данных нужно создать дескриптор, чтобы оптимизировать
его использование.
+/
struct CmdCreateBuffer
{
    public
    {
        /// Указатель на дескриптор буфера, куда будет передан объект.
        Buffer* buffer;

        /// Вид данных, который будет использоваться буфер.
        BufferUsage type;
    }
}

/++
Команда выделения памяти под отрисовочный буфер.

Буфер должен содержать вид данных renderbuffer, иначе,
библиотека пропустит шаг с выделением памяти.
+/
struct CmdAllocRenderBuffer
{
    public
    {
        /// Буфер. куда нужно выделить место.
        Buffer buffer;

        /// Ширина и высота отрисовочного буфера.
        uint width, height;
    }
}

/++
Команда привязки буфера к кадровому буферу.

Место привязываемого буфера должен иметь тип `renderBuffer`,
иначе привязка просто проигнорируется.
+/
struct CmdFrameBufferBindBuffer
{
    public
    {
        /// Кадровый буфер.
        FrameBuffer frameBuffer;

        /// Привязываемый отрисовочный буфер.
        Buffer buffer;
    }
}

/++ 
Команда очищения кадрового буфера определённым цветом.
+/
struct CmdClearFrameBuffer
{
    public
    {
        /// Кадровый буфер, который будет залит одним цветом.
        FrameBuffer frameBuffer;

        /// Каким цветом нужно залить кадровый буфер.
        float[4] color;
    }
}

/++
Команда отправки кадрового буфер в подготовительный кадр (поверхность).

Подготовительный кадр - кадр, недоступный под отрисовку, но доступен для
передачи на него других кадровых буферов, т.к. этот первый должен подготовлен
к отправке на поверхность окна.
+/
struct CmdBlitFrameBufferToSurface
{
    public
    {
        /// Кадровый буфер
        FrameBuffer frameBuffer;

        /// Позиция региона копирования.
        int x, y;

        /// Ширина региона копирования.
        uint width, height;
    }
}

/// Тип генерируемого кода.
enum CodeType
{
    /++
    Нативный драйверу код. 

    Это означает, что код содержащий в массиве, можно использовать
    только конкретному драйверу на текущем устройстве, и не может
    быть использован в других компьютерах, драйвера которого
    отличаются от текущего устройства.
    +/
    native,

    /++
    SPRI-V код.

    Общедоступный код, который можно использовать на других девайсах,
    поддерживающий SPRI-V технологию.
    +/
    spirv
}

/// Типы стадий шейдеров.
enum StageType
{
    /// Вершинный шейдер.
    vertex,

    /// Фрагментный шейдер
    fragment,

    /// Геометрический шейдер.
    geometry,

    compute
}

/++
Результат компиляции.

Содержит в себе код ошибки и сообщение с ошибкой, 
если код отличен от нуля.
+/
struct CompileStatus
{
    public
    {
        /// Код ошибки. Отличие от нуля - признак наличие ошибки.
        int errorid;

        /// Сообщение ошибки.
        string log;
    }
}

/++ 
Команда компилирования исходника шейдера в бинарный вид.
+/
struct CmdCompileShaderModule
{
    public
    {
        /// Исходный код шейдера.
        string source;

        /// Указатель на структуру результата компиляции.
        /// 
        /// Если указатель нулевой, то статус будет передан
        /// в другие структуру проверки результата.
        CompileStatus* status;

        /// Какой тип бинарного кода нужно сгенерировать.
        CodeType outputType;

        /// Какую стандию рендернига предусматривает шейдер.
        StageType stage;

        /// Указатель на массив. Массиву не нужно заранее место,
        /// команда автоматически выделит место.
        void[]* code;

        /// Используемый компилятор. На данный момент, не используется.
        string compiler;
    }
}

/++
Команда создания шейдерного модуля.
+/
struct CmdCreateShaderModule
{
    public
    {
        /// Указатель на дескриптор, куда будет помещён объект.
        ShaderModule* shaderModule;

        /// Тип кода, передоваемого в шейдерный модуль.
        CodeType codeType;

        /// Стадия, который предусматривает шейдерный модуль.
        StageType stage;

        /// Бинарный код шейдера.
        void[] code;

        /// Результат связки кода с шейдерным модулем. 
        CompileStatus* status;
    }
}

/++
Команда уничтожения шейдерного модуля.
+/
struct CmdDestroyShaderModule
{
    public
    {
        /// Указатель на дескриптор.
        ///
        /// Команда автоматически удалит объект и
        /// выставит указатель на нуль.
        ShaderModule* shaderModule;
    }
}

/++
Структура описания прямоугольника для проекции сцены.
+/
struct Viewport
{
    public
    {
        /// Позиция проекции.
        float x = 0.0f, y = 0.0f;

        /// Высоты проекции.
        float width, height;

        /// Глубина проекции.
        float minDepth = 0.0f, maxDepth = 1.0f;
    }
}

/// Ограничение видимых фрагментов.
struct Scissor
{
    public
    {
        /// Смещение видимых фрагментов.
        float[2] offset = [0.0f, 0.0f];

        /// Граница видимых фрагментов.
        float[2] extent = [float.nan, float.nan];
    }
}

/// Состояние видимых границ в сцене.
struct ViewportState
{
    public
    {
        /// Проекция в сцене.
        Viewport viewport;

        /// Ограничение видимых фрагментов.
        Scissor scissor;
    }
}

/// Режим отрисовки полигонов.
enum PolygonMode
{
    /// Рисовать полные полигоны.
    fill,

    /// Рисовать только границы полигон.
    line,

    /// Рисовать только вершины границ полигонов.
    point
}

/++
Состояние стадии растеризации кадра.
+/
struct RasterizationState
{
    public
    {
        /// Состояние проверка глубины.
        bool depthClampEnable = false;

        /// Состояние отключение растеризации.
        bool rasterizerDiscardEnable = false;

        /// Метод растеризации полигонов.
        PolygonMode polygonMode = PolygonMode.fill;

        /// Ширина линий.
        float lineWidth = 1.0f;
    }
}

/++
Переменные смешивания,
+/
enum BlendFactor
{
    Zero,
    One,
    SrcColor,
    OneMinusSrcColor,
    DstColor,
    OneMinusDstColor,
    SrcAlpha,
    OneMinusSrcAlpha,
    DstAlpha,
    OneMinusDstAlpha,
    ConstantColor,
    OneMinusConstantColor,
    ConstantAlpha,
    OneMinusConstanceAlpha
}

/// Оператор смешиваний.
enum BlendOp
{
    add,
    subtract,
    reverseSubtract,
    min,
    max
}

/++ 
Описание стадии смешиваний цветов.
+/
struct ColorBlendAttachmentState
{
    public
    {
        /// Состояние нужности стадии.
        bool blendEnable = true;

        BlendFactor srcColorBlendFactor;
        BlendFactor dstColorBlendFactor;
        BlendOp colorBlendOp;

        BlendFactor srcAlphaBlendFactor;
        BlendFactor dstAlphaBlendFactor;
        BlendOp alphaBlendOp;

        /// Константы смешиваний.
        float[4] blendConstansts;
    }
}

/++
Описание стадии шейдера для конвеера.
+/
struct ShaderStage
{
    public
    {
        /// Шейдерный модуль.
        ShaderModule shaderModule;

        /// В какой стадии нужно использовать шейдерный модуль.
        StageType stage;

        /// Точка входа программы шейдерного модуля.
        string entryPoint;
    }
}

/++
Описание привязки.
+/
struct AttachmentDescription
{
    public
    {
        bool sampleEnable = false;
        uint samples;
    }
}

/++
Формат динамических данных шейдера.
+/
enum UniformFormat
{
    Byte,
    UnsignedByte,
    Short,
    UnsignedShort,
    Int,
    UnsignedInt,
    Float,
    Double
}

/// Тип описания данных конвеера.
enum WriteDescriptType
{
    /// Описание динамических данных стадий конвеера.
    uniform,

    /// Описание привязки изображений для стадий конвеера.
    imageSampler
}

/++
Описание динамических данных стадий конвеера.
+/
struct UniformDescript
{
    public
    {
        /// Какой буфер будет отвечает
        Buffer buffer;

        /// К каким стадиям шейдера применяется динамические данные.
        StageType stageFlags;

        /// Смещение от начало данных буфера.
        size_t offset;

        /// Размер блока данных для стадии конвеера.
        size_t size;
    }
}

interface ImageView
{

}

/++
Описание привязки картинки к конвееру.
+/
struct ImageViewDescript
{
    public
    {
        /// Картинка.
        Image image;

        /// Описание видимости картинки.
        Sampler sampler;
    }
}

/++
Описание привязок динамических данный к конвееру.
+/
struct WriteDescription
{
    public
    {
        /// Тип привязки.
        WriteDescriptType type;

        /// Номер привязки в шейдере.
        uint binding;

        union
        {
            UniformDescript uniform;
            ImageViewDescript imageView;
        }

        this(
            WriteDescriptType type,
            uint binding,
            UniformDescript uniform
        )
        {
            this.type = type;
            this.binding = binding;
            this.uniform = uniform;
        }

        this(
            WriteDescriptType type,
            uint binding,
            ImageViewDescript imageView
        )
        {
            this.type = type;
            this.binding = binding;
            this.imageView = imageView;
        }
    }
}

/++
Описание создания конвеера.
+/
struct CmdCreatePipeline
{
    public
    {
        /// Указатель на дескриптор, куда будет помещён объект.
        Pipeline* pipeline;

        /// Шейдерные стадии, которые будут включены в конвеер.
        ShaderStage[] stages;

        /// Описание видимых проекций.
        ViewportState viewportState;

        /// Описание растеризации.
        RasterizationState rasterization;

        /// Описание стадии смешивания.
        ColorBlendAttachmentState colorBlendAttachment;

        /// Описание видимости вершинных аттрибутов.
        VertexInputBindingDescription vertexInput;

        /// Описание привязки цветового пространства.
        AttachmentDescription colorAttachment;

        /// Описание привязки динамических данных.
        WriteDescription[] writeDescriptions;

        /// Указатель на старый конвеер. Если указатель пуст, то создаётся новый,
        /// иначе, будет отредактирован текущий (тогда не нужен указатель на дескриптор
        /// т.к. будет обновлён текущий)
        Pipeline* oldPipeline = null;
    }
}

/++
Команда выделения места под буфер.

Для выделения памяти для отрисовояного буфера используйте
команду `CmdAllocRenderBuffer`.
+/
struct CmdAllocBuffer
{
    public
    {
        /// Буфер, куда будет выделена память.
        Buffer buffer;

        /// Необходимый размер выделяемой памяти.
        size_t size;
    }
}

/++
Команда изменения данных буфера.
+/
struct CmdBuffSetData
{
    public
    {
        /// Буфер.
        Buffer buffer;

        /// Смещение с начало блока данных буфера, куда будет залиты данные.
        size_t offset;

        /// Размер блока данных.
        size_t size;

        /// Данные для буфера.
        void[] data;
    }
}

/++
Тип доступа к данным.

Можно одновременно записать оба бита:
---
immutable readWrite = MapAccess.readBit | MapAccess.writeBit;
---
+/
enum MapAccess
{
    /// Доступ на чтение.
    readBit,

    /// Доступ на запись.
    writeBit
}

/++
Команда на открытие данных в пространство пользователя.

После открытия, не забудьте закрыть доступ, чтобы синхронизировать
данные между пространством пользователя и  устройством.
+/
struct CmdMapBuffer
{
    public
    {
        /// Буфер, откуда будет переведёны данные в пространство пользователя.
        Buffer buffer;

        /// Смещение с начала данных.
        size_t offset;

        /// Размер блока данных.
        size_t length;

        /// Флаги доступа к данным. 
        /// 
        /// Это нужно для некоторых оптимизаций.
        MapAccess access;

        /// Указатель на данные, куда будет помещены данные.
        void[]* space;
    }
}

/++
Отвязка данных буфера из пространсва пользователя.
+/
struct CmdUnmapBuffer
{
    public
    {
        /// Буфер, откуда нужно закрыть доступ.
        Buffer buffer;
    }
}

/// Информация о участке рендеринга.
struct RenderArea
{
    public
    {
        /// Смещение с начальной точки рендеринга.
        float[2] offset;

        /// Размер рендеринга.
        float[2] extent;
    }
}

/++
Команда начала рендеринга кадра.
+/
struct CmdRenderPassInfo
{
    public
    {
        /// Используемый кадровый буффер.
        FrameBuffer frameBuffer;

        /// Зона рендеринга.
        RenderArea renderArea;

        /// Цвет очищения.
        float[4] clearColor;
    }
}

enum PrimitiveTopology
{
    points,
    lines,
    triangles,
    trianglesFan,
    lineStrip
}

/++
Команда отрисовки объекта.
+/
struct CmdDraw
{
    public
    {
        /// Используемый конвеер.
        Pipeline pipeline;

        /// Данные вершин.
        Buffer vertexBuffer;

        /// Данные элементов. Если указать,
        /// рендеринг будет без их использования.
        Buffer elementBuffer;

        /// Количество вершин/элементов, которые должны войти в рендеринг.
        uint count;

        /// Тип рисуемых объектов.
        PrimitiveTopology topology = PrimitiveTopology.triangles;
    }
}

// struct CmdMultiDraw
// {
//     public
//     {
//         Pipeline pipeline;

//         Buffer[] vertexBuffers;

//         Buffer[] elementBuffers;

//         uint[] count;

//         /// Тип рисуемых объектов.
//         PrimitiveTopology topology = PrimitiveTopology.triangles;
//     }
// }

/++ 
Команда копирования данных между двумя буферами.
+/
struct CmdCopyBuffer
{
    public
    {
        /// Буфера, между которыми будет копирование данных.
        Buffer read, write;

        /// Смещения по копированиям.
        size_t srcOffset, dstOffset;

        /// Размер блока данных.
        size_t size;
    }
}

/++
Типы изображений.
+/
enum ImageType
{
    /// Линейное изображение.
    image1D,

    /// Двумерное изображение.
    image2D,


    /// Трёмерное изображение.
    image3D
}

/// Форматы данных.
enum InternalFormat
{
    r8,
    r16,
    rg8,
    rg16,
    rgb4,
    rgb5,
    rgb8,
    rgb10,
    rgb12,
    rgb16,
    rgba2,
    rgba4,
    rgba8,
    rgba10,
    rgba12,
    rgba16,
    r16f,
    rg16f,
    rgb16f,
    rgba16f,
    r32f,
    rg32f,
    rgb32f,
    rgba32f
}

/++
Команда создания и выделения памяти под изображение.

Если не нужно выделять место под данные изображения,
выставьте высоты в нуль.
+/
struct CmdCreateImage
{
    public
    {
        /// Тип изображения.
        ImageType type;

        /// Ширина.
        uint width;

        /// Высота.
        uint height;

        /// Глубина.
        uint depth;

        /// Формат данных в изобаражении.
        InternalFormat format;

        /// Указатель на дескриптор, куда будет выложен объект.
        Image* image;
    }
}

/++
Команда редактирования свойств изображения.
+/
struct CmdEditImage
{
    public
    {
        Image image;

        /// Ширина.
        uint width;

        /// Высота.
        uint height;

        /// Глубина.
        uint depth;

        /// Формат данных в изобаражении.
        InternalFormat format;
    }
}

/++
Команда уничтожения изображения.
+/
struct CmdDestroyImage
{
    public
    {
        Image* image;
    }
}

/++ 
Команда привязки данных к изображению.
+/
struct CmdBindImageMemory
{
    public
    {
        /// Дескриптор изображения, куда нужно поместить данные.
        Image image;

        /// Данные изображения.
        void[] data;

        /// Смещение с начало региона данных.
        size_t offset;

        /// Размер региона данных.
        size_t length;
    }
}

/++
Тип фильтрации текстур.
+/
enum FilterType
{
    linear,
    nearest
}

/++
Тип отсечения координат текстуры.
+/
enum SamplerAddressMode
{
    repeat,
    mirroredRepeat,
    clampToEdge,
    mirrorClampToEdge,
    clampToBorder
}

/++
Команда создания семплера.
+/
struct CmdCreateSampler
{
    public
    {
        /// Изображение, для которого будет создан семплер.
        Image image;

        /// Указатель на дескриптор, куда будет помещён объект.
        Sampler* sampler;

        /// Тип фильтрации.
        FilterType magFilter;

        /// Тип фильтрации.
        FilterType minFilter;

        /// Тип отсечения координат.
        SamplerAddressMode  addressModeU,
                            addressModeV,
                            addressModeW;

    }
}

/++
Команда редактирования сэмплера.
+/
struct CmdEditSampler
{
    public
    {
        /// Дескриптор сэмплера.
        Sampler sampler;

        /// Тип фильтрации.
        FilterType magFilter;

        /// Тип фильтрации.
        FilterType minFilter;

        /// Тип отсечения координат.
        SamplerAddressMode  addressModeU,
                            addressModeV,
                            addressModeW;
    }
}

/++
Команда уничтожения сэмплера.
+/
struct CmdDestroySampler
{
    public
    {
        /// Указатель на сэмплер.
        Sampler* sampler;
    }
}

/++
Динамические данные конвеера.
+/
struct PipelineDynamicState
{
    import std.typecons;

    public
    {
        Nullable!ViewportState viewportState;
        Nullable!ColorBlendAttachmentState colorBlendAttachment;
    }
}

/++
Команда редактирования дин. данных конвеера.
+/
struct CmdPipelineEdit
{
    public
    {
        /// Дескриптор конвеера.
        Pipeline pipeline;

        /// Динамические данные.
        PipelineDynamicState state;
    }
}

/++
Команда уничтожения буфера данных.
+/
struct CmdDestroyBuffer
{
    public
    {
        /// Указатель на дескриптор.
        Buffer* buffer;
    }
}

/++
Команда уничтожения конвеера.
+/
struct CmdDestroyPipeline
{
    public
    {
        /// Указатель на дескриптор.
        Pipeline* pipeline;
    }
}

/++ 
Команда уничтожения кадрового буффера.
+/
struct CmdDestroyFrameBuffer
{
    public
    {
        /// Указатель на дескриптор.
        FrameBuffer* frameBuffer;
    }
}

struct ImageViewInfo
{
    public
    {
        Image image;
        ImageType viewType;
        InternalFormat format;

        size_t baseLevel;
        size_t numLevels;

        size_t baseLayer;
        size_t numLayers;
    }
}

struct CmdCreateImageView
{
    public
    {
        ImageView* imageView;

        ImageViewInfo viewInfo;
    }
}

struct CmdUpdateImageView
{
    public
    {
        ImageView imageView;

        ImageViewInfo viewInfo;
    }
}

struct CmdExt
{
    public
    {
        string extension;
        ulong id;
        void[] data;
    }
}

struct CmdCreateComputePipeline
{
    public
    {
        Pipeline* pipeline;
        ShaderStage stage;
    }
}

/++
Структура описания команды.
+/
struct Command
{
    public
    {
        /// Номер команды.
        CommandType type;

        /// Описание команды.
        union
        {
            CmdPresentInfo presentInfo;
            CmdCreateFrameBuffer createFrameBufferInfo;
            CmdCreateBuffer createBufferInfo;
            CmdAllocRenderBuffer allocRenderBufferInfo;
            CmdFrameBufferBindBuffer frameBufferBindBuffer;
            CmdClearFrameBuffer clearFrameBufferInfo;
            CmdBlitFrameBufferToSurface blitFrameBufferToSurfaceInfo;
            CmdCreateShaderModule createShaderModuleInfo;
            CmdDestroyShaderModule destroyShaderModuleInfo;
            CmdCompileShaderModule compileShaderModuleInfo;
            CmdCreatePipeline createPipelineInfo;
            CmdAllocBuffer allocBufferInfo;
            CmdBuffSetData buffSetDataInfo;
            CmdMapBuffer mapBufferInfo;
            CmdUnmapBuffer unmapBufferInfo;
            CmdRenderPassInfo renderPassBegin;
            CmdDraw drawInfo;
            CmdCopyBuffer copyBufferInfo;
            CmdCreateImage createImageInfo;
            CmdBindImageMemory bindImageMemoryInfo;
            CmdCreateSampler createSamplerInfo;
            CmdPipelineEdit pipelineEditInfo;
            CmdDestroyImage destroyImageInfo;
            CmdDestroySampler destroySamplerInfo;
            CmdDestroyBuffer destroyBufferInfo;
            CmdDestroyPipeline destroyPipelineInfo;
            CmdDestroyFrameBuffer destroyFrameBufferInfo;
            CmdEditSampler editSamplerInfo;
            CmdCreateImageView createImageViewInfo;
            CmdUpdateImageView updateImageViewInfo;
            CmdExt extensionInfo;
            CmdCreateComputePipeline createCompute;
        }

        debug
        {
            string file;
            int line;

            this(CommandType type, string file = __FILE__, int line = __LINE__)
            {
                this.type = type;
                this.file = file;
                this.line = line;
            }

            this(T)(CommandType type, T info, string file = __FILE__, int line = __LINE__)
            {
                this.type = type;
                this.file = file;
                this.line = line;

                static foreach (member; __traits(allMembers, typeof(this)))
                {
                    static if (is(typeof(__traits(getMember, typeof(this), member)) == T))
                    {
                        __traits(getMember, typeof(this), member) = info;
                    }
                }
            }
        } else
        {
            this(CommandType type)
            {
                this.type = type;
            }

            this(T)(CommandType type, T info)
            {
                this.type = type;

                static foreach (member; __traits(allMembers, typeof(this)))
                {
                    static if (is(typeof(__traits(getMember, typeof(this), member)) == T))
                    {
                        __traits(getMember, typeof(this), member) = info;
                    }
                }
            }
        }
    }
}

/++
Структура командного контейнера.

Должен содержать в себе команды одного типа очереди,
иначе, будет проигнорирован.
+/
struct CommandPool
{
    import core.sync.semaphore;

    public
    {
        /// К какому типу очереди относится контейнер команд.
        /// 
        /// При отличии типа контейнера и очереди, все его команды
        /// будут проигнорированы.
        QueueFlag cmdFlag;

        /// Команды.
        Command[] commands;

        /// Сенаморф, который будет использован по окончанию обработки
        /// команд в этом контейнере.
        Semaphore semaphore;
    }
}

/++
Дескриптор изображения.
+/
interface Image
{
    /// Ширина изображения.
    immutable(uint) width() @safe nothrow;

    /// Высота изображения. 
    immutable(uint) height() @safe nothrow;

    /// Глубина изображения.
    immutable(uint) depth() @safe nothrow;
}

/// Дескриптор сэмплера. 
interface Sampler
{

}

/// Формат вершинных данных.3wsssssssssssssd e3
enum VertexAttributeFormat
{
    Byte,
    UnsignedByte,
    Short,
    UnsignedShort,
    Int,
    UnsignedInt,
    Float,
    Double
}

/++
Описание вершинных данных.
+/
struct VertexInputAttributeDescription
{
    public
    {
        /// Номер локации вершины.
        uint location;

        /// Формат данных.
        VertexAttributeFormat format;

        /// Количество компонентов в вершине.
        uint components;

        /// Смещение от начала семпла.
        uint offset;
    }
}

/++ 
Описание привязки вершинных данных к конвееру.
+/
struct VertexInputBindingDescription
{
    public
    {
        uint binding;
        uint stride;
        VertexInputAttributeDescription[] attributes;
    }
}

/++
Дескриптор конвеера.
+/
interface Pipeline
{
    public
    {

    }
}

/++
Дескриптор кадрового буфера.
+/
interface FrameBuffer
{
    public
    {

    }
}

/++
Дескриптор буфера данных.
+/
interface Buffer
{
    public
    {
        immutable(size_t) length() @safe;
    }
}

/++
Дескриптор шейдерного модуля.
+/
interface ShaderModule
{
    public
    {
        /// Стадия шейдерного модуля.
        StageType stage();
    }
}

/++
Объект очереди.
+/
interface Queue
{
    public
    {
        /++
        Отправка контейрена команд в очередь.

        Контейнер складывается в очередь и будет исполнен
        в тот момент. когда устройство начнёт обрабатывать
        команды.
        +/
        void submit(CommandPool pool);

        /++
        Отправка и исполнение контейнера команд.

        Исполнять только в том потоке, в котором
        было создано устройство.
        +/
        void handle(CommandPool pool);

        /++
        Заставляет ждать поток конца обработки очереди.
        +/
        void wait();

        /++
        Отправка контейрена команд в очередь.

        Контейнер складывается в очередь и будет исполнен
        в тот момент. когда устройство начнёт обрабатывать
        команды.
        +/
        void submit(shared CommandPool pool) shared;

        /++
        Отправка и исполнение контейнера команд.

        Исполнять только в том потоке, в котором
        было создано устройство.
        +/
        void handle(shared CommandPool pool) shared;

        /++
        Заставляет ждать поток конца обработки очереди.
        +/
        void wait() shared;
    }
}

/++
Дескриптор устройства.
+/
interface Device
{
    public
    {
        /++
        Функция получения очередей, куда нужно высылать команды.
        +/
        Queue[] getQueues();

        /++
        Функция обработки всех очередей.
        +/
        void handleQueues();
    }
}

/++
Режим отправки кадра.
+/
enum PresentMode
{
    immediate,
    fifo,
    mailbox
}

/++
Формат кадровых буферов.
+/
struct Format
{
    public
    {
        uint redSize;
        uint greenSize;
        uint blueSize;
        uint alphaSize;
        uint depthSize;
        uint stencilSize;
        uint sampleCount = 4;
    }
}

/++
Формат поверхности.
+/
struct SurfaceFormat
{
    public
    {
        Format format;
        PresentMode presentMode;
    }
}

/++
Выбирает более подходящий формат по шаблону.

Params:
    formats = Список форматов поверхности.
    format = Необходимый формат из списка.
+/
SurfaceFormat[] chooseFormat(SurfaceFormat[] formats, SurfaceFormat format)
{
    SurfaceFormat[] result;

    foreach (fmt; formats)
    {
        if (fmt.format.redSize == format.format.redSize &&
            fmt.format.greenSize == format.format.greenSize &&
            fmt.format.blueSize == format.format.blueSize &&
            fmt.format.alphaSize == format.format.alphaSize &&
            fmt.presentMode == format.presentMode)
        {
            result ~= fmt;
        }
    }

    return result;
}

/++
Выбирает более подходящий формат по шаблону.

Params:
    surface = Поверхность, к которому нужно подобрать формат.
    format = Необходимый формат из списка.
+/
SurfaceFormat[] chooseFormat(Surface surface, SurfaceFormat format)
{
    return chooseFormat(surface.getFormats(), format);
}

/++
Информация о создании цепочки кадров для отправки в окно программы.
+/
struct CreateSwapChainInfo
{
    public
    {
        /// Необходимый формат кадров.
        Format format;

        /// Метод отправки кадров.
        PresentMode presentMode;

        /// Размер кадров.
        uint[2] extend;
    }
}

/++
Дескриптор цепочки кадров.
+/
interface SwapChain
{
    public
    {
    }
}

/++
Дескриптор поверхности окна.
+/
interface Surface
{
    public
    {
        /++
        Выдаёт доступные форматы поверхности.
        +/
        SurfaceFormat[] getFormats();

        /++
        Создаёт цепочку кадров для девайса.

        Params:
            device      =   Девайс, которому нужно создать цепочку 
                            кадров для отправки в окно программы.
            createInfo  =   Информация о создании цепочки кадров.
        +/
        SwapChain createSwapChain(Device device, CreateSwapChainInfo createInfo);
    }
}

/++
Информации о слоях валидации ошибок и данных.
+/
struct ValidationLayer
{
    public
    {
        /// Имя.
        string name;

        /// Включена ли опция по умолчанию.
        bool enabled = false;
    }
}

/++
Экземпляр работы с библиотекой.
+/
interface Instance
{
    public
    {
        /// Получить доступные расширения.
        string[] getExtensions();

        /// Получить доступные физические устройства.
        PhysDevice[] enumeratePhysicalDevices();

        /// Получить дескриптор устройства из дескриптора информации устройства.
        /// 
        /// Params:
        ///     pdevice = Физическое устройство.
        ///     createInfo = Информация о создании дескриптора устройства.
        Device createDevice(PhysDevice pdevice, DeviceCreateInfo createInfo);

        /// Получить доступные слои валидации ошибок и данных.
        ValidationLayer[] enumerateValidationLayers();
    }
}

/++
Инфомация о создании экземпляра библиотеки.
+/
struct CreateInstanceInfo
{
    public
    {
        /// Информация о приложении и движке, на котором работает программа.
        ApplicationInfo applicationInfo;

        /// Расширения, которые нужно включить в библиотеку.
        ///
        /// Если указаны те, которых нет, они будут проигнорированы.
        string[] extensions;
    }
}

alias CreateInstanceFunc = void function(immutable CreateInstanceInfo, RCIAllocator, ref Instance);
alias ExtensionsEnumFunc = string[] function(RCIAllocator allocator);

/++
Создаёт экземпляр работы с библиотекой.
+/
CreateInstanceFunc createInstance;

ExtensionsEnumFunc enumerateExtensions;