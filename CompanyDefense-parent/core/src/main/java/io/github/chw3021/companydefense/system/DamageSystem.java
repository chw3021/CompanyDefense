package io.github.chw3021.companydefense.system;

import com.badlogic.ashley.core.Entity;
import com.badlogic.ashley.core.Family;
import com.badlogic.ashley.systems.IteratingSystem;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.component.HealthComponent;

public class DamageSystem extends IteratingSystem {
    public DamageSystem() {
        super(Family.all(HealthComponent.class).get());
    }

    @Override
    protected void processEntity(Entity entity, float deltaTime) {
        HealthComponent health = entity.getComponent(HealthComponent.class);
        DamageComponent damage = entity.getComponent(DamageComponent.class);

        if (damage != null) {
            // 물리 데미지 처리
            float physicalDamage = Math.max(0, damage.physicalDamage - health.physicalDefense);
            // 마법 데미지 처리
            float magicDamage = Math.max(0, damage.magicDamage - health.magicDefense);

            // 총 피해량 계산
            float totalDamage = physicalDamage + magicDamage;
            health.health -= totalDamage;

            // 데미지 컴포넌트 초기화 (한 번만 적용)
            damage.physicalDamage = 0;
            damage.magicDamage = 0;

            // 체력이 0 이하일 경우 처리
            if (health.health <= 0) {
                getEngine().removeEntity(entity); // 엔티티 제거
            }
        }
    }
}
