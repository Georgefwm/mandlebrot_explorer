#version 450

layout(set=3, binding=0) uniform UBO {
    ivec2 resolution;
    vec2  centerPoint;
    float zoomSize;
    int   maxIterations;
    int   usePerturbation;
    int   useGreyscale;
};

layout(location=0) out vec4 FragColor;

vec2 complexMultiply(vec2 a, vec2 b)
{
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x); 
}

float mandlebrot(vec2 c)
{
    vec2 z = vec2(0.0);

    // A returned value of -1 signifies a non-escape within maxIterations.
    float escapeIteration = -1.0;

    for (int i = 0; i < maxIterations; i++)
    {
        z = complexMultiply(z, z) + c;

        if (dot(z, z) > 4.0)
        {
            escapeIteration = float(i);
            break;
        }
    }

    return escapeIteration;
}

float mandlebrotPerturbation(vec2 c, vec2 dc)
{
    vec2 z  = vec2(0.0);
    vec2 dz = vec2(0.0);

    float escapeIteration = -1.0;

    for (int i = 0; i < maxIterations; i++)
    {
        dz = complexMultiply(2.0 * z + dz, dz) + dc;  
        // dz = complexMultiply(dz, dz) + dc + 2.0 * complexMultiply(z, dz);
        
        z = complexMultiply(z, z) + c; // this could be precomputed since it's constant for the whole image
        
        if (dot(dz, dz) > 4.0)
        { 
            escapeIteration = float(i);
            break;
        }
    }

    return escapeIteration;
}

void main()
{
    vec2 normalisedPosition = (2.0 * gl_FragCoord.xy - resolution.xy) / resolution.xy;
    
    // Normally I like to use verbose var names, but shader people seem to not...
    vec2 c  = centerPoint;
    vec2 dc = normalisedPosition * zoomSize; 

    float value = usePerturbation == 1 ? mandlebrotPerturbation(c, dc) : mandlebrot(c + dc);

    vec3 color = vec3(0.0);

    if (value >= 0.0)
    {
        if (useGreyscale == 1) color = vec3(value / float(maxIterations));
        else color = 0.5 + 0.5 * cos(pow(zoomSize, 0.22) * value * 0.05 + vec3(3.0, 3.5, 4.0));
    }
        
	FragColor = vec4(color, 1.0);
}
