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
    float4      worldPosition;
    float3      normal;
    float2      texcoord;
    float4      color;
};

struct GBufferVertexUniforms {
    float4x4 viewProjectionMatrix;
    float4x4 modelMatrix;
    float3x3 normalMatrix;
};

struct GBufferOut {
    float4 albedo [[color(0)]];
    float4 normal [[color(1)]];
    float4 position  [[color(2)]];
    float4 depth [[color(3)]];
    float4 id [[color(4)]];
    float4 edge [[color(5)]];
};

struct VertexUniforms {
    float4x4 viewProjectionMatrix;
    float4x4 modelMatrix;
    float3x3 normalMatrix;
};

struct PanelVertexIn {
    float3      position    [[ attribute(0) ]];
    float4      color       [[ attribute(1) ]];
    float2      texcoord       [[ attribute(2) ]];
};


vertex VertexOut gBufferVert //(const device VertexIn *vertices[[buffer(0)]],
//                             const device VertexUniforms &uniforms [[buffer(1)]],
//                             unsigned int vid [[vertex_id]]) {
    (VertexIn vin [[ stage_in ]],
     constant GBufferVertexUniforms& uniforms [[ buffer(1) ]]) {

    VertexOut out;
//    VertexIn vin = vertices[vid];

//    float4 inPosition = float4(vin.position, 1.0);
//    out.position = uniforms.viewProjectionMatrix * inPosition;
//    float3 normal = vin.normal;
//    float3 eyeNormal = normalize(uniforms.normalMatrix * normal);
//
//    out.normal = eyeNormal;
//    out.texcoord = vin.texcoord;
//    out.worldPosition = uniforms.modelMatrix * inPosition;
//
//    return out;
    
    float4 worldPosition =  uniforms.modelMatrix * float4(vin.position, 1.0);
    out.worldPosition = worldPosition;
    out.position = uniforms.viewProjectionMatrix * worldPosition;
    out.normal = uniforms.normalMatrix * vin.normal;
    out.texcoord = vin.texcoord;
    return out;
}

fragment GBufferOut gBufferFrag(VertexOut in[[stage_in]], texture2d<float> albedo_texture [[texture(0)]]) {
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
//    float4 albedo = albedo_texture.sample(linear_sampler, in.texcoord);
    GBufferOut output;
    
    output.albedo = float4(0.0, 0.0, 0.0, 1.0);
    output.normal = float4(in.normal, 1.0);
//    output.normal = float4(1.0, 1.0, 0.0, 1.0);
    output.position = in.worldPosition;
    
    //    bunny
    float dmax = 0.8;
    float dmin = 0.3;
    float depth = (in.position.z / in.position.w + 1.0) * 0.5;
    depth = max(min(depth, dmax), dmin);
    depth = (depth-dmin)/(dmax-dmin);
    output.depth = float4(float3(depth), 1.0);
    output.id = float4(0.64, 0.64, 0.63, 1.0);
    
    return output;
}

vertex VertexOut lambertVertex(VertexIn vIn [[ stage_in ]],constant VertexUniforms& uniforms [[ buffer(1) ]]) {
    
    VertexOut vOut;
    float4 worldPosition = uniforms.modelMatrix * float4(vIn.position, 1);
    vOut.position = uniforms.viewProjectionMatrix * worldPosition;
    vOut.worldPosition = worldPosition;
    vOut.normal = uniforms.normalMatrix * vIn.normal;
    vOut.texcoord = float2(vIn.texcoord.xy);
    return vOut;

}

fragment float4 lambertFragment(VertexOut vIn [[ stage_in ]], texture2d<float> texture [[ texture(0) ]]) {
    //    float diffuseFactor = saturate(dot(vIn.normal, -lightDirection));
//    constexpr sampler colorSampler(address::repeat);
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
    float4 color = texture.sample(linear_sampler, vIn.texcoord);
//    float gray = color.x * 0.29 + color.y * 0.58 + color.z * 0.11;
//    color = float4(gray, gray, gray, 1.0);
    
    const int filtersize = 3;
    int margin = (filtersize - 1) / 2;
    int karnel[filtersize*filtersize] = { 1, 1, 1, 1, -8, 1, 1, 1, 1};
//    for(int h = margin; h < originalImg.height() -margin; h++ ) {
//        for(int w = margin; w < originalImg.width() -margin; w++ ) {
//            int i = 0;
//            int sum = 0;
//            for(int p = -margin; p <= margin; p++){
//                for(int q = -margin; q <= margin; q++){
//                    QColor originalcolor(originalImg.pixel(w+p, h+q));
//
//                    sum+= originalcolor.red()*kernel[i];
//                    i++;
//                }
//            }
//            sum = abs(sum);
//            if(sum > 255) sum = 255;
//            QColor color = QColor(sum, sum, sum);
//            filteredImg.setPixelColor(w,h,color);
//        }
//    }
    
    return color;
}

vertex VertexOut basic_vertex_function(const device PanelVertexIn *vertices [[ buffer(0) ]],
                                       uint vertexID [[ vertex_id ]]) {
    VertexOut vOut;
    vOut.position = float4(vertices[vertexID].position, 1);
    vOut.color = vertices[vertexID].color;
    vOut.texcoord = vertices[vertexID].texcoord;
    return vOut;
}

fragment float4 basic_fragment_function(VertexOut vIn [[ stage_in ]], /*constant TimeUnifrom &time [[buffer(0)]],*/ texture2d<float> texture [[ texture(0) ]]) {
//    constexpr sampler colorSampler(address::repeat);
//    float4 color = texture.sample(linear_sampler, vIn.texcoord);
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
    float4 color = texture.sample(linear_sampler, vIn.texcoord);
//    float4 color = texture.sample(colorSampler, vIn.color.xy+time.time);
//    vIn.color = float4(time, time, time, 1);
//    return float4(color.xy, time.time2, 1);
//    return vIn.color;
    return color;
//    return float4(0, 0, 0, 1);
}


