package io.github.chw3021.companydefense.tower;

import java.util.List;

import com.badlogic.ashley.core.Entity;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.Batch;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.scenes.scene2d.Actor;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.InputListener;
import com.badlogic.gdx.scenes.scene2d.Touchable;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.component.HealthComponent;
import io.github.chw3021.companydefense.component.TransformComponent;
import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.stage.StageParent;


public class Tower extends Actor {
    private Texture texture;
    
    
    private String name;
    private float physicalAttack;
    private float magicAttack;
    private float attackSpeed;
    private float attackRange;
	private int towerGrade=1;
	private float attackCooldown; // 다음 공격까지 남은 시간
    private String attackType = "closest";
    private DamageComponent damageComponent;
    private StageParent stage;
    private String team;

    public Tower(TowerDto towerDto, int towerLevel, int gridSize, StageParent stage) {
        this.physicalAttack = towerDto.getTowerPhysicalAttack()*(1+towerDto.getTowerAttackMult()*towerLevel);
        this.magicAttack = towerDto.getTowerMagicAttack()*(1+towerDto.getTowerAttackMult()*towerLevel);
        this.attackSpeed = towerDto.getTowerAttackSpeed();
        this.attackRange = towerDto.getTowerAttackRange()*gridSize;
        this.attackType = towerDto.getAttackType();
        this.name = towerDto.getTowerName();
        this.towerGrade = towerDto.getTowerGrade();
        this.team = towerDto.getTeam();
        damageComponent = new DamageComponent(physicalAttack, magicAttack);
        
        Gdx.app.postRunnable(() -> {  // 메인 스레드에서 실행
            Pixmap originalPixmap = new Pixmap(Gdx.files.internal(towerDto.getTowerImagePath()));

            Pixmap resizedPixmap = new Pixmap((int) (gridSize * 0.8), (int) (gridSize * 0.8), originalPixmap.getFormat());
            resizedPixmap.drawPixmap(originalPixmap,
                                     0, 0, originalPixmap.getWidth(), originalPixmap.getHeight(),
                                     0, 0, resizedPixmap.getWidth(), resizedPixmap.getHeight());

            texture = new Texture(resizedPixmap);  // OpenGL 컨텍스트 내에서 실행
        	this.setTouchable(Touchable.enabled);
        	this.setSize(gridSize * 0.8f, gridSize * 0.8f);
        });
        this.stage = stage;
	}



    public Tower(Tower other) {
        this.physicalAttack = other.physicalAttack;
        this.magicAttack = other.magicAttack;
        this.attackSpeed = other.attackSpeed;
        this.attackRange = other.attackRange;
        this.attackCooldown = other.attackCooldown;
        this.damageComponent = other.damageComponent;
        this.name = other.name;
        this.texture = other.texture;
        this.towerGrade = other.towerGrade;
        this.stage = other.stage;
        this.team = other.team;
        setPosition(other.getX(), other.getY());
        // 필요한 필드를 추가적으로 복사

        addListener(new InputListener() {
        	
        	
            @Override
            public boolean touchDown(InputEvent event, float x, float y, int pointer, int button) {
            	((Tower)event.getTarget()).isDragging = true;
            	((Tower)event.getTarget()).dragStartPos = new Vector2(getX(), getY());
            	return true;
            }

            @Override
            public void touchDragged(InputEvent event, float x, float y, int pointer) {
                // 가이드 원 위치 갱신
            	((Tower)event.getTarget()).dragStartPos.set(getX() + x, getY() + y);
            }

            @Override
            public void touchUp(InputEvent event, float x, float y, int pointer, int button) {
            	((Tower)event.getTarget()).isDragging = false; // 드래그 종료
                stage.onTowerClicked(Tower.this); 
            }
        });
    }
	// 적에게 피해를 주는 attack 메서드
    public void attack(Enemy target) {
        target.addDamage(damageComponent); // 적에게 데미지를 추가
    }

    // 업데이트 메서드 (적을 탐지하고 공격하는 로직 포함)
    public void update(float delta, Array<Enemy> enemies) {
        attackCooldown -= delta;

        if (attackCooldown <= 0) {
            attackCooldown = 1 / attackSpeed; // 공격 속도 기반 쿨타임 재설정

            // 범위 내에서 타겟 탐색
            Enemy target = findTarget(enemies,attackType);
            if (target != null) {
                attack(target); // 공격
            }
        }
    }

    // 범위 내 타겟을 찾는 메서드
    private Enemy findTarget(Array<Enemy> enemies, String attackType) {
        Enemy bestTarget = null;
        float bestValue = attackType.equals("closest") ? Float.MAX_VALUE : 0; // 초기값 설정

        for (Enemy enemy : enemies) {
            Vector2 enemyPos = enemy.getPosition();
            float distance = Vector2.dst(getX(), getY(), enemyPos.x, enemyPos.y);
            
            
            // 타워 범위 내에 있는 적만 고려
            if (distance <= attackRange) {
                if (attackType.equals("closest")) {
                    if (distance < bestValue) {
                        bestValue = distance;
                        bestTarget = enemy;
                    }
                } else if (attackType.equals("furthest")) {
                    if (distance > bestValue) {
                        bestValue = distance;
                        bestTarget = enemy;
                    }
                } else if (attackType.equals("strongest")) {
                    HealthComponent health = enemy.getComponent(HealthComponent.class);
                    if (health != null && health.health > bestValue) {
                        bestValue = health.health;
                        bestTarget = enemy;
                    }
                }
            }
        }

        return bestTarget;
    }

    public boolean upgrade(Array<Tower> availableTowers) {
        if (Math.random() < 0.2) { // 20% 확률 성공
            for (Tower newTower : availableTowers) {
                if (newTower.towerGrade == this.towerGrade + 1) {
                    this.physicalAttack = newTower.physicalAttack;
                    this.magicAttack = newTower.magicAttack;
                    this.attackSpeed = newTower.attackSpeed;
                    this.attackRange = newTower.attackRange;
                    this.towerGrade = newTower.towerGrade;
                    this.texture = newTower.texture; // 새로운 타워 텍스처 적용
                    return true;
                }
            }
        } else {
        	System.out.println("gory");
        	remove(); // 타워 삭제
        }
		return false;
    }
    
    private boolean isDragging = false;
    private Vector2 dragStartPos;
    
    public void renderGuide(ShapeRenderer shapeRenderer) {
        if (isDragging) {
            shapeRenderer.begin(ShapeRenderer.ShapeType.Line);
            shapeRenderer.setColor(Color.RED);
            shapeRenderer.circle(dragStartPos.x, dragStartPos.y, attackRange);
            shapeRenderer.end();
        }
    }
    public void render(SpriteBatch batch) {
        float textureX = getX() + texture.getWidth() * 0.2f; // 텍스처 중심으로 x 조정
        float textureY = getY() + texture.getHeight() * 0.2f; // 텍스처 중심으로 y 조정
        batch.draw(texture, textureX, textureY); // 조정된 좌표로 그리기
      
    }
    @Override
    public void draw(Batch batch, float parentAlpha) {
        if (texture != null) {
            float textureX = getX() + texture.getWidth() * 0.2f; // 텍스처 중심으로 x 조정
            float textureY = getY() + texture.getHeight() * 0.2f; // 텍스처 중심으로 y 조정
            batch.draw(texture, textureX, textureY, getWidth(), getHeight());
        }
    }
    public void dispose() {
        texture.dispose();
    }

    public void setPosition(Vector2 position) {
        setPosition(position.x, position.y);
    }

    public Vector2 getPosition() {
        return new Vector2(this.getX(), this.getY());
    }
    // 추가적인 getter와 setter
    public float getPhysicalAttack() {
        return physicalAttack;
    }

    public void setPhysicalAttack(float physicalAttack) {
        this.physicalAttack = physicalAttack;
    }

    public float getMagicAttack() {
        return magicAttack;
    }

    public void setMagicAttack(float magicAttack) {
        this.magicAttack = magicAttack;
    }

    public float getAttackSpeed() {
        return attackSpeed;
    }

    public void setAttackSpeed(float attackSpeed) {
        this.attackSpeed = attackSpeed;
    }
    public float getAttackRange() {
		return attackRange;
	}

	public void setAttackRange(float attackRange) {
		this.attackRange = attackRange;
	}
	public String getName() {
	    return name;
	}

	public int getGrade() {
	    return towerGrade;
	}

}
