package io.github.chw3021.companydefense.skill.hr;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.tower.Tower;

public class CoffeeInfusionSkill extends SkillParent {
	
	private StageParent stage;
	
    public CoffeeInfusionSkill(SkillDto dto, StageParent stage) {
        super(dto);
        this.stage = stage;
    }

    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
    	stage.towers.forEach(targetTower -> {
            if (tower.getPosition().dst(targetTower.getPosition()) <= range) {
            	targetTower.increaseAttackSpeed(mult, duration);
                showSkillEffect(stage, targetTower.getX(), targetTower.getY(), targetTower.getWidth(), targetTower.getHeight());
            }
    	});
    }
}
