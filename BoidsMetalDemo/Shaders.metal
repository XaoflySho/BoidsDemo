//
//  Shaders.metal
//  BoidsMetalDemo
//
//  Created by XiaoFei Shao on 2025/8/25.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float2 position;
    float4 color;
    float2 velocity;
};

// 分离力计算函数
float2 calculateSeparation(uint id, device Vertex *vertices, uint numVertices, 
                          float separationDist, float maxSpeed, float maxForce) {
    Vertex self = vertices[id];
    float2 separation = float2(0.0);
    int separationCount = 0;
    
    for (uint i = 0; i < numVertices; i++) {
        if (i == id) continue;
        Vertex other = vertices[i];
        float2 offset = other.position - self.position;
        float dist = length(offset);
        
        if (dist < separationDist && dist > 0.001) {
            float2 diff = normalize(offset);
            diff /= dist;  // 距离越近，力越强
            separation -= diff;  // 负号表示排斥
            separationCount++;
        }
    }
    
    if (separationCount > 0) {
        separation /= float(separationCount);
        if (length(separation) > 0.001) {
            separation = normalize(separation) * maxSpeed - self.velocity;
            if (length(separation) > maxForce) {
                separation = normalize(separation) * maxForce;
            }
        }
    }
    
    return separation;
}

// 对齐力计算函数
float2 calculateAlignment(uint id, device Vertex *vertices, uint numVertices,
                         float neighborDist, float maxSpeed, float maxForce) {
    Vertex self = vertices[id];
    float2 alignment = float2(0.0);
    int neighborCount = 0;
    
    for (uint i = 0; i < numVertices; i++) {
        if (i == id) continue;
        Vertex other = vertices[i];
        float2 offset = other.position - self.position;
        float dist = length(offset);
        
        if (dist < neighborDist && dist > 0.001) {
            alignment += other.velocity;
            neighborCount++;
        }
    }
    
    if (neighborCount > 0) {
        alignment /= float(neighborCount);
        if (length(alignment) > 0.001) {
            alignment = normalize(alignment) * maxSpeed;
            alignment = alignment - self.velocity;
            if (length(alignment) > maxForce) {
                alignment = normalize(alignment) * maxForce;
            }
        }
    }
    
    return alignment;
}

// 凝聚力计算函数
float2 calculateCohesion(uint id, device Vertex *vertices, uint numVertices,
                        float neighborDist, float maxSpeed, float maxForce) {
    Vertex self = vertices[id];
    float2 cohesion = float2(0.0);
    int neighborCount = 0;
    
    for (uint i = 0; i < numVertices; i++) {
        if (i == id) continue;
        Vertex other = vertices[i];
        float2 offset = other.position - self.position;
        float dist = length(offset);
        
        if (dist < neighborDist && dist > 0.001) {
            cohesion += other.position;
            neighborCount++;
        }
    }
    
    if (neighborCount > 0) {
        cohesion /= float(neighborCount);  // 计算邻居质心
        cohesion = cohesion - self.position;  // 指向质心的向量
        if (length(cohesion) > 0.001) {
            cohesion = normalize(cohesion) * maxSpeed - self.velocity;
            if (length(cohesion) > maxForce) {
                cohesion = normalize(cohesion) * maxForce;
            }
        }
    }
    
    return cohesion;
}

// 边界避让力计算函数
float2 calculateBoundaryForce(float2 position, float margin, float boundaryStrength) {
    float2 boundaryForce = float2(0.0);
    
    // 左边界
    if (position.x < -1.0 + margin) {
        float strength = ((-1.0 + margin) - position.x) / margin;
        boundaryForce.x += strength * boundaryStrength;
    }
    // 右边界
    if (position.x > 1.0 - margin) {
        float strength = (position.x - (1.0 - margin)) / margin;
        boundaryForce.x -= strength * boundaryStrength;
    }
    // 下边界
    if (position.y < -1.0 + margin) {
        float strength = ((-1.0 + margin) - position.y) / margin;
        boundaryForce.y += strength * boundaryStrength;
    }
    // 上边界
    if (position.y > 1.0 - margin) {
        float strength = (position.y - (1.0 - margin)) / margin;
        boundaryForce.y -= strength * boundaryStrength;
    }
    
    return boundaryForce;
}

kernel void updateVertices(device Vertex *vertices [[buffer(0)]],
                           uint id [[thread_position_in_grid]],
                           uint numVertices [[threads_per_grid]]) {
    if (id >= numVertices) return;

    Vertex self = vertices[id];

    // 参数配置
    float neighborDist = 0.1;        // 邻居距离
    float separationDist = 0.05;     // 分离距离
    float maxSpeed = 0.008;          // 最大速度
    float maxForce = 0.001;          // 最大力
    float margin = 0.12;             // 边界范围
    float boundaryStrength = 0.004;  // 边界力强度
    
    // 权重参数
    float separationWeight = 1.5;
    float alignmentWeight = 1.0;
    float cohesionWeight = 1.0;

    // 计算三种 Boids 力
    float2 separationForce = calculateSeparation(id, vertices, numVertices, 
                                                separationDist, maxSpeed, maxForce) * separationWeight;
    
    float2 alignmentForce = calculateAlignment(id, vertices, numVertices,
                                              neighborDist, maxSpeed, maxForce) * alignmentWeight;
    
    float2 cohesionForce = calculateCohesion(id, vertices, numVertices,
                                            neighborDist, maxSpeed, maxForce) * cohesionWeight;
    
    // 计算边界避让力
    float2 boundaryForce = calculateBoundaryForce(self.position, margin, boundaryStrength);

    // 应用所有力
    self.velocity += separationForce + alignmentForce + cohesionForce + boundaryForce;

    // 速度限制
    float speed = length(self.velocity);
    if (speed > maxSpeed) {
        self.velocity = normalize(self.velocity) * maxSpeed;
    }
    
    // 避免完全静止
    if (speed < 0.0005) {
        float angle = float(id) * 0.1;
        self.velocity = float2(cos(angle), sin(angle)) * 0.001;
    }

    // 更新位置
    self.position += self.velocity;

    // 硬边界 - 防止 boids 完全超出边界
    if (self.position.x > 1.0) self.position.x = 1.0;
    if (self.position.x < -1.0) self.position.x = -1.0;
    if (self.position.y > 1.0) self.position.y = 1.0;
    if (self.position.y < -1.0) self.position.y = -1.0;

    vertices[id] = self;
}

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float pointSize [[point_size]];
};

vertex VertexOut vertex_main(const device Vertex* vertices [[buffer(0)]], uint id [[vertex_id]]) {
    VertexOut out;
    out.position = float4(vertices[id].position, 0, 1);
    out.color = vertices[id].color;
    out.pointSize = 6.0;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}

