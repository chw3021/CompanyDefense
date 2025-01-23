package io.github.chw3021.companydefense.component;

import com.badlogic.ashley.core.Component;

public class DamageComponent implements Component {
    public float physicalDamage;
    public float magicDamage;

    public DamageComponent(float physicalDamage, float magicDamage) {
        this.physicalDamage = physicalDamage;
        this.magicDamage = magicDamage;
    }

	public float getPhysicalDamage() {
		return physicalDamage;
	}

	public void setPhysicalDamage(float physicalDamage) {
		this.physicalDamage = physicalDamage;
	}

	public float getMagicDamage() {
		return magicDamage;
	}

	public void setMagicDamage(float magicDamage) {
		this.magicDamage = magicDamage;
	}
    
    
}