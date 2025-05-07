#version 450

void main()
{
    vec4 position = vec4(0, 0, 0, 1);

    switch (gl_VertexIndex) {
        case 0: position = vec4(-1.0, -1.0, 0, 1); break;
        case 1: position = vec4( 1.0, -1.0, 0, 1); break;
        case 2: position = vec4(-1.0,  1.0, 0, 1); break;
        case 3: position = vec4(-1.0,  1.0, 0, 1); break;
        case 4: position = vec4( 1.0, -1.0, 0, 1); break;
        case 5: position = vec4( 1.0,  1.0, 0, 1); break;
    }

    gl_Position = position;
}
