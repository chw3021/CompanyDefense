package io.github.chw3021.companydefense.skill.dv;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.tower.Tower;

public class CodeInterpretationSkill extends SkillParent {
    public CodeInterpretationSkill(SkillDto dto) {
        super(dto);
    }

    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
        for (Enemy enemy : enemies) {
            enemy.addDamage(new DamageComponent(0.0f,(tower.getMagicAttack() * mult)));
        }
    }
}