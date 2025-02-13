package io.github.chw3021.companydefense.skill.dv;

import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.Timer;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.tower.Tower;

public class AlgorithmCreationSkill extends SkillParent {
	private StageParent stage;
    public AlgorithmCreationSkill(SkillDto dto, StageParent stage) {
        super(dto);
        this.stage = stage;
    }

    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
        if (enemies.size > 0) {
            Enemy target = enemies.get(0);
            for (int i = 0; i < duration; i++) {
                Timer.schedule(new Timer.Task() {
                    @Override
                    public void run() {
                        target.addDamage(new DamageComponent(0.0f,(tower.getMagicAttack() * mult)));
                    }
                }, i);
            }
        }
    }
}