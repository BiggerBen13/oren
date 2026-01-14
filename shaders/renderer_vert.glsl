#version 410 core

uniform mat4 mvp;

layout (location = 0) in vec3 aPos; // the position variable has attribute position 0
layout (location = 1) in vec2 uv;
layout (location = 2) in mat4 transformation;

out vec2 uvCoords; // specify a color output to the fragment shader

void main()
{
    mat4 trans = mat4(1.0);
    gl_Position = mvp * transformation * vec4(aPos, 1.0); // mvp * transformation * 
    uvCoords = uv;
}
