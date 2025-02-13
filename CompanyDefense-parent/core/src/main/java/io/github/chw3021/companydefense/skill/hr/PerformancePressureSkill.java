package io.github.chw3021.companydefense.skill.hr;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.tower.Tower;

public class PerformancePressureSkill extends SkillParent {
	private StageParent stage;
	
    public PerformancePressureSkill(SkillDto dto, StageParent stage) {
        super(dto);
        this.stage = stage;
    }

    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
        Tower targetTower = findStrongestTowerNearby(tower); // 버프 대상 찾기
        if (targetTower != null) {
            targetTower.increaseAttackPower(mult, duration);
            targetTower.increaseAttackSpeed(mult, duration);
            targetTower.reduceSkillCooldown(mult, duration);
            
            showSkillEffect(stage, targetTower.getPosition(), targetTower.getWidth()*0.2f, targetTower.getHeight()*0.2f);
        }
    }
    
    private Tower findStrongestTowerNearby(Tower tower) {
        Tower strongestTower = null;
        float maxAttack = 0;

        for (Tower t : stage.towers) {
            float attackPower = t.getPhysicalAttack() + t.getMagicAttack();
            if (attackPower > maxAttack) {
                maxAttack = attackPower;
                strongestTower = t;
            }
        }
        
        return strongestTower;
    }
}
