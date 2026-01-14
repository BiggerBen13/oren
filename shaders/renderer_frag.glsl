#version 410 core

layout (location = 0) in vec2 uvCoords; 
layout (location = 0) out vec4 FragColor;

void main()
{
    FragColor = vec4(uvCoords, 0.0, 1.0);
} 
