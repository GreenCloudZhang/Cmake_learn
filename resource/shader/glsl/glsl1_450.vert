#version 450

struct UBO{
    mat4 projectionMatrix;
    mat4 modelMatrix;
    mat4 viewMatrix;
}

layout(binding=0, std140) uniform type_ubo
{
    layout(row_major) UBO ubo;
}ubo;

layout(location=0) in vec3 in_var_POSITION0;
layout(location=1) in vec3 in_var_COLOR0;
layout(location=0) out vec3 out_var_COLOR0;

void main()
{
    gl_Position = (vec4(in_var_POSITION0, 1.0) * ubo.ubo.modelMatrix * ubo.ubo.viewMatrix * ubo.ubo.projectionMatrix);
    out_var_COLOR0 = in_var_COLOR0 * float(uint(gl_VertexID));
}