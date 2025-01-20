package io.github.chw3021.companydefense.component;

import com.badlogic.ashley.core.Component;

public class HealthComponent implements Component {
    public float health;
    public float physicalDefense;
    public float magicDefense;

    public HealthComponent(float health, float physicalDefense, float magicDefense) {
        this.health = health;
        this.physicalDefense = physicalDefense;
        this.magicDefense = magicDefense;
    }
}