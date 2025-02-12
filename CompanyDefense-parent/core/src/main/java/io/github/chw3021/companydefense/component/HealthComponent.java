package io.github.chw3021.companydefense.component;

import com.badlogic.ashley.core.Component;
import com.badlogic.gdx.utils.Timer;

public class HealthComponent implements Component {
    public float health;
    public float physicalDefense;
    public float magicDefense;
	public float maxHealth;

    public HealthComponent(float health, float physicalDefense, float magicDefense) {
        this.maxHealth = health;
        this.health = health;
        this.physicalDefense = physicalDefense;
        this.magicDefense = magicDefense;
    }
    
    public void damage(DamageComponent damageComponent) {
        // 물리 공격력에 대한 방어력 적용
        float effectivePhysicalDamage = damageComponent.getPhysicalDamage() * (1 - physicalDefense / (physicalDefense + 100));
        
        // 마법 공격력에 대한 방어력 적용
        float effectiveMagicDamage = damageComponent.getMagicDamage() * (1 - magicDefense / (magicDefense + 100));
        
        // 최종 피해 계산 (물리 + 마법 피해)
        float totalDamage = effectivePhysicalDamage + effectiveMagicDamage;
        
        // 체력에서 피해 차감
        health -= totalDamage;

        // 최소 체력이 0을 넘지 않도록 보장
        if (health < 0) {
            health = 0;
        }
    }
    
}
