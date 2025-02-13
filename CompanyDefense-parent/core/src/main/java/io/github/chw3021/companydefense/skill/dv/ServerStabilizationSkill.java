package io.github.chw3021.companydefense.skill.dv;

import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.Timer;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.tower.Tower;

public class ServerStabilizationSkill extends SkillParent {
	private StageParent stage;
    public ServerStabilizationSkill(SkillDto dto, StageParent stage) {
        super(dto);
        this.stage = stage;
    }

    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
        for (Enemy enemy : enemies) {
            if (enemy.getPosition().dst(tower.getPosition()) <= range) {
                for (int i = 0; i < duration * 10; i++) {
                    Timer.schedule(new Timer.Task() {
                        @Override
                        public void run() {
                            enemy.addDamage(new DamageComponent(0.0f,(tower.getMagicAttack() * mult)));
                        }
                    }, i * 0.1f);
                }
            }
        }
        showSkillEffect(stage, tower.getX()+tower.getWidth()*0.2f, tower.getY()+tower.getHeight()*0.6f, tower.getWidth()*0.8f, tower.getHeight()*0.8f);
    }
}