package io.github.chw3021.companydefense.skill.dv;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.tower.Tower;

public class CodeExecutionSkill extends SkillParent {
	private StageParent stage;
    public CodeExecutionSkill(SkillDto dto, StageParent stage) {
        super(dto);
        this.stage = stage;
    }

    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
        for (Enemy enemy : enemies) {
            if (enemy.getPosition().dst(tower.getPosition()) <= range) {
                enemy.addDamage(new DamageComponent(0.0f,(tower.getMagicAttack() * mult)));
            }
        }
    }
}