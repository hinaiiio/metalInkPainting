//
//  Shaders.metal
//  MetalSandbox
//
//  Created by Hina on 2018/08/05.
//  Copyright © 2018 Hina. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// Basic Struct to match our Swift type
// This is what is passed into the Vertex Shader
struct VertexIn {
    float3 position;
    float4 color;
};
// What is returned by the Vertex Shader
// This is what is passed into the Fragment Shader
struct VertexOut {
    float4 position [[ position ]];
    float4 color;
};

struct TimeUnifrom {
    float time;
    float time2;
};

vertex VertexOut basic_vertex_function(const device VertexIn *vertices [[ buffer(0) ]],
                                       uint vertexID [[ vertex_id ]]) {
    VertexOut vOut;
    vOut.position = float4(vertices[vertexID].position,1);
    vOut.color = vertices[vertexID].color;
    return vOut;
}

fragment float4 basic_fragment_function(VertexOut vIn [[ stage_in ]], constant TimeUnifrom &time [[buffer(0)]], texture2d<float> texture [[ texture(0) ]]) {
    constexpr sampler colorSampler(address::repeat);
    float4 color = texture.sample(colorSampler, vIn.color.xy+time.time);
//    vIn.color = float4(time, time, time, 1);
    return float4(color.xy, time.time2, 1);
}
