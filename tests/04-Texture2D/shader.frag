#version 450

layout (location = 0) in vec2 tex;

layout(binding = 0) uniform sampler2D texture0;

layout (location = 0) out vec4 fragColor;

void main()
{
    fragColor = texture(texture0, tex);
}