package io.github.chw3021.companydefense.system;

import com.badlogic.ashley.core.Entity;
import com.badlogic.ashley.core.Family;
import com.badlogic.ashley.systems.IteratingSystem;

import io.github.chw3021.companydefense.component.HealthComponent;

public class DamageSystem extends IteratingSystem {
    public DamageSystem() {
        super(Family.all(HealthComponent.class).get());
    }

    @Override
    protected void processEntity(Entity entity, float deltaTime) {
        HealthComponent health = entity.getComponent(HealthComponent.class);

        // 예제: 물리 데미지 처리
        float incomingDamage = 50; // 예제 데미지 값
        float effectiveDamage = Math.max(0, incomingDamage - health.physicalDefense);
        health.health -= effectiveDamage;

        if (health.health <= 0) {
            // 엔티티 제거 (죽음 처리)
            getEngine().removeEntity(entity);
        }
    }
}
