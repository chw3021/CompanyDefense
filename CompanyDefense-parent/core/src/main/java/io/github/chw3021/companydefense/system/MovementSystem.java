package io.github.chw3021.companydefense.system;

import com.badlogic.ashley.core.Entity;
import com.badlogic.ashley.core.Family;
import com.badlogic.ashley.systems.IteratingSystem;
import io.github.chw3021.companydefense.component.TransformComponent;
//
//public class MovementSystem extends IteratingSystem {
//    public MovementSystem() {
//        super(Family.all(TransformComponent.class).get());
//    }
//
//    @Override
//    protected void processEntity(Entity entity, float deltaTime) {
//        TransformComponent transform = entity.getComponent(TransformComponent.class);
//
//        // 이동 업데이트
//        transform.position.add(transform.velocity.x * deltaTime, transform.velocity.y * deltaTime);
//    }
//}
