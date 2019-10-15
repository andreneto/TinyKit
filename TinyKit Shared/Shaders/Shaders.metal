//
//  Shaders.metal
//  TinyKit
//
//  Created by André Carneiro on 30/09/19.
//  Copyright © 2019 André Carneiro. All rights reserved.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
//    out.position.z = -8.0;
    out.texCoord = in.texCoord;
//    out.position = float4(0,0,0,1);

    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
//                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> texture     [[ texture(TextureIndexColor) ]], sampler baseColorSampler [[sampler(0)]])
{
    
//    constexpr sampler colorSampler(mip_filter::linear,
//                                   mag_filter::linear,
//                                   min_filter::linear);
    
    

    half4 colorSample   = texture.sample(baseColorSampler, in.texCoord.xy);

//    return float4(0,1,1,0);
    return float4(colorSample);
}
