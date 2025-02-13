package io.github.chw3021.companydefense.skill.dv;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.tower.Tower;

public class DebuggingSkill extends SkillParent {
    public DebuggingSkill(SkillDto dto) {
        super(dto);
    }

    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
        if (enemies != null) {
    	    Enemy target = tower.target;
    	    target.addDamage(new DamageComponent(0.0f,(tower.getMagicAttack() * mult)));  
        }
    }
}
//new DamageComponent(tower.getMagicAttack() * mult)
//tower.getMagicAttack() * mult