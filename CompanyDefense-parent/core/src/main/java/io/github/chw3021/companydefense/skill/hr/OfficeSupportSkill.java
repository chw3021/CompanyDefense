package io.github.chw3021.companydefense.skill.hr;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.tower.Tower;

public class OfficeSupportSkill extends SkillParent {

	private StageParent stage;
	
    public OfficeSupportSkill(SkillDto dto, StageParent stage) {
        super(dto);
        this.stage = stage;
    }

    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
        for (Enemy enemy : enemies) {
            if (tower.getPosition().dst(enemy.getPosition()) <= range) {
                enemy.reduceDefense(mult, mult, duration);
                showSkillEffect(stage, enemy.getPosition(), tower.getWidth()*0.5f, tower.getWidth()*0.5f);
            }
        }
    }

}
