//
//  Shaders.metal
//  MetalSandbox
//
//  Created by Hina on 2018/08/05.
//  Copyright © 2018 Hina. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define lightDirection float3(1, -4, -5)

// Basic Struct to match our Swift type
// This is what is passed into the Vertex Shader
struct VertexIn {
    float3      position    [[ attribute(0) ]];
    float3      normal      [[ attribute(1) ]];
    float2      texcoord    [[ attribute(2) ]];
};
// What is returned by the Vertex Shader
// This is what is passed into the Fragment Shader
struct VertexOut {
    float4      position    [[ position ]];
    float3      worldPosition;
    float3      normal;
    float2      texcoord;
    float4      color;
};

struct VertexUniforms {
    float4x4 viewProjectionMatrix;
    float4x4 modelMatrix;
    float3x3 normalMatrix;
};

struct ModelConstraints {
    float4x4 modelMatrix;
};

struct SceneConstraints {
    float4x4 projectionMatrix;
};

//vertex VertexOut basic_vertex_function(const device VertexIn *vertices [[ buffer(0) ]],
//                                       uint vertexID [[ vertex_id ]]) {
//    VertexOut vOut;
//    vOut.position = float4(vertices[vertexID].position,1);
//    vOut.color = vertices[vertexID].color;
//    return vOut;
//}

//fragment float4 basic_fragment_function(VertexOut vIn [[ stage_in ]], constant TimeUnifrom &time [[buffer(0)]], texture2d<float> texture [[ texture(0) ]]) {
//    constexpr sampler colorSampler(address::repeat);
//    float4 color = texture.sample(colorSampler, vIn.color.xy+time.time);
////    vIn.color = float4(time, time, time, 1);
//    return float4(color.xy, time.time2, 1);
//}

vertex VertexOut lambertVertex(VertexIn vIn [[ stage_in ]],
                               constant VertexUniforms& uniforms [[ buffer(1) ]]) {
    VertexOut vOut;
    float4 worldPosition = uniforms.modelMatrix * float4(vIn.position, 1);
    vOut.position = uniforms.viewProjectionMatrix * worldPosition;
    vOut.worldPosition = worldPosition.xyz;
    vOut.normal = uniforms.normalMatrix * vIn.normal;
    vOut.texcoord = float2(vIn.texcoord.xy);
    return vOut;
}

fragment float4 lambertFragment(VertexOut vIn [[ stage_in ]], texture2d<float> texture [[ texture(0) ]]) {
//    float diffuseFactor = saturate(dot(vIn.normal, -lightDirection));
    constexpr sampler colorSampler(address::repeat);
    float4 color = texture.sample(colorSampler, vIn.texcoord);
    return color;
}

