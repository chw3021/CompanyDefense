package io.github.chw3021.companydefense.skill.dv;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.tower.Tower;

public class DebuggingSkill extends SkillParent {
	private StageParent stage;
    public DebuggingSkill(SkillDto dto, StageParent stage) {  	
        super(dto);
        this.stage = stage;
    }

    //단일타겟스킬
    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
    	Enemy target = tower.target;
        if (target != null) {
        	DamageComponent damage = new DamageComponent(0.0f,(tower.getMagicAttack() * mult));
    	    shotProjectile(stage, tower.getPosition(), target, damage, tower.getWidth()*0.5f, tower.getWidth()*0.5f);
        }
    }
}