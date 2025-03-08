package io.github.chw3021.companydefense.tower;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.Animation;
import com.badlogic.gdx.graphics.g2d.Batch;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.math.Rectangle;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.scenes.scene2d.Actor;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.InputListener;
import com.badlogic.gdx.scenes.scene2d.Touchable;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.Timer;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.component.HealthComponent;
import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillFactory;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.stage.StageParent;


public class Tower extends Actor {
    private Texture texture;
    private Texture originalTexture;
    
    
    private String name;
    private float physicalAttack;
    private float magicAttack;
    private float basePhysicalAttack;
    private float baseMagicAttack;
    private float attackSpeed;
    private float baseAttackSpeed;
    private float attackRange;
	private int towerGrade=1;
	private float attackCooldown; // 다음 공격까지 남은 시간
    private String attackType = "closest";
    private DamageComponent damageComponent;
    private StageParent stage;
    private String team;
    private String imagePath;
    private String attackImagePath;
    private String towerPortraitPath;
    
    private Animation<TextureRegion> attackAnimation;
    private float elapsedTime = 0;
    private boolean isAttacking = false;
    
    public Enemy target;
    
    private Boolean isMergable = false;
    private int gridSize;

    private SkillParent skill;
    
    private TextureRegion currentFrame;  // 🔹 현재 프레임을 저장하는 변수
    
    
	public Tower(TowerDto towerDto, int towerLevel, int gridSize, StageParent stage, SkillDto skillDto) {
        this.physicalAttack = towerDto.getTowerPhysicalAttack()*(1+towerDto.getTowerAttackMult()*(towerLevel-1));
        this.magicAttack = towerDto.getTowerMagicAttack()*(1+towerDto.getTowerAttackMult()*(towerLevel-1));
        this.basePhysicalAttack = physicalAttack;
        this.baseMagicAttack = magicAttack;
        this.attackSpeed = towerDto.getTowerAttackSpeed();
        this.baseAttackSpeed = attackSpeed;
        this.attackRange = towerDto.getTowerAttackRange()*gridSize;
        this.gridSize = gridSize;
        this.attackType = towerDto.getAttackType();
        this.name = towerDto.getTowerName();
        this.towerGrade = towerDto.getTowerGrade();
        this.team = towerDto.getTeam();
        this.imagePath = towerDto.getTowerImagePath();
        this.attackImagePath = towerDto.getTowerAttackImagePath();
        this.towerPortraitPath = towerDto.getTowerPortraitPath();
        this.skill = SkillFactory.createSkill(skillDto, stage); // 스킬 생성

        damageComponent = new DamageComponent(physicalAttack, magicAttack);
        
        Gdx.app.postRunnable(() -> {  // 메인 스레드에서 실행
            Pixmap originalPixmap = new Pixmap(Gdx.files.internal(towerDto.getTowerImagePath()));

            Pixmap resizedPixmap = new Pixmap((int) (gridSize), (int) (gridSize), originalPixmap.getFormat());
            resizedPixmap.drawPixmap(originalPixmap,
                                     0, 0, originalPixmap.getWidth(), originalPixmap.getHeight(),
                                     0, 0, resizedPixmap.getWidth(), resizedPixmap.getHeight());

            texture = new Texture(resizedPixmap);  // OpenGL 컨텍스트 내에서 실행
            originalTexture = texture;
        	this.setTouchable(Touchable.enabled);
        	this.setSize(gridSize, gridSize);
            setAttackAnimation(attackImagePath);
        });
        this.stage = stage;
        
	}


	public Tower(Tower other) {
        this.physicalAttack = other.physicalAttack;
        this.magicAttack = other.magicAttack;
        this.basePhysicalAttack = other.basePhysicalAttack;
        this.baseMagicAttack = other.baseMagicAttack;
        this.attackSpeed = other.attackSpeed;
        this.baseAttackSpeed = other.baseAttackSpeed;
        this.attackRange = other.attackRange;
        this.gridSize = other.gridSize;
        this.attackCooldown = other.attackCooldown;
        this.damageComponent = other.damageComponent;
        this.name = other.name;
        this.texture = other.texture;
        this.originalTexture = other.originalTexture;
        this.towerGrade = other.towerGrade;
        this.stage = other.stage;
        this.team = other.team;
        this.imagePath = other.imagePath;
        this.attackImagePath =other.attackImagePath;
        this.towerPortraitPath = other.towerPortraitPath;
        this.attackAnimation = other.attackAnimation;
        this.skill = other.skill;
        setPosition(other.getX(), other.getY());
        // 필요한 필드를 추가적으로 복사

        addListener(new InputListener() {
        	
        	
            @Override
            public boolean touchDown(InputEvent event, float x, float y, int pointer, int button) {
            	((Tower)event.getTarget()).isDragging = true;
            	((Tower)event.getTarget()).dragStartPos = new Vector2(getX() + x, getY() + y);
                stage.onTowerClicked(Tower.this); 
            	return true;
            }
            @Override
            public void touchDragged(InputEvent event, float x, float y, int pointer) {
                Tower thisTower = (Tower) event.getTarget();
                thisTower.dragStartPos.set(getX() + x, getY() + y); // 커서 위치로 이동

                // 현재 커서 위치에 있는 타워 확인 (자기 자신 제외)
                Tower targetTower = findTowerAtPosition(getX() + x, getY() + y);

                if (targetTower != null && targetTower != thisTower 
                    && targetTower.name.equals(thisTower.name) 
                    && targetTower.towerGrade == thisTower.towerGrade) {
                    isMergable = true;
                } else {
                    isMergable = false;
                }
            }
            
            @Override
            public void touchUp(InputEvent event, float x, float y, int pointer, int button) {
                Tower thisTower = (Tower) event.getTarget();
                thisTower.isDragging = false; // 드래그 종료

                // 놓은 위치에 있는 타워 찾기 (자기 자신 제외)
                Tower targetTower = findTowerAtPosition(getX() + x, getY() + y);

                if (targetTower != null && targetTower != thisTower // 자기 자신 제외
                    && targetTower.name.equals(thisTower.name) 
                    && targetTower.towerGrade == thisTower.towerGrade) {
                    
                    // 두 타워를 합쳐서 상위 등급 타워로 변경
                    Tower mergedTower = mergeTowers(targetTower);
                    
                    if (mergedTower != null) {
                        targetTower.remove(); // 기존 타워 삭제
                        thisTower.remove(); // 현재 타워 삭제
                    }
                }
            }
        });
    }
	// 🔹 공격력 증가 (중첩 가능)
	private int attackPowerBuffCount = 0;
	public void increaseAttackPower(float mult, float duration) {
	    float addedPhysical = basePhysicalAttack * mult;
	    float addedMagic = baseMagicAttack * mult;

	    physicalAttack += addedPhysical;
	    magicAttack += addedMagic;
	    attackPowerBuffCount++; // 버프 스택 증가

	    Timer.schedule(new Timer.Task() {
	        @Override
	        public void run() {
	            attackPowerBuffCount--; // 버프 스택 감소
	            if (attackPowerBuffCount == 0) { // 마지막 버프 해제 시 원래 값으로 복구
	                stage.upgradeTowerByTeamLevel(Tower.this, team);
	            }
	        }
	    }, duration);
	}

	// 🔹 공격 속도 증가 (중첩 가능)
	private int attackSpeedBuffCount = 0;
	public void increaseAttackSpeed(float mult, float duration) {
	    float addedSpeed = baseAttackSpeed * mult;

	    attackSpeed += addedSpeed;
	    attackSpeedBuffCount++;

	    Timer.schedule(new Timer.Task() {
	        @Override
	        public void run() {
	            attackSpeedBuffCount--;
	            if (attackSpeedBuffCount == 0) {
	                attackSpeed = baseAttackSpeed;
	            }
	        }
	    }, duration);
	}

	// 🔹 스킬 쿨타임 감소 (중첩 가능)
	private int cooldownReductionBuffCount = 0;
	private float cooldownMultiplier = 1.0f; // 현재 적용된 쿨타임 감소 비율
	public void reduceSkillCooldown(float mult, float duration) {
	    if (skill != null) {
	        cooldownMultiplier *= (1 - mult);
	        skill.setCooldown(skill.getBaseCooldown() * cooldownMultiplier);
	        cooldownReductionBuffCount++;

	        Timer.schedule(new Timer.Task() {
	            @Override
	            public void run() {
	                cooldownReductionBuffCount--;
	                if (cooldownReductionBuffCount == 0) {
	                    skill.setCooldown(skill.getBaseCooldown());
	                    cooldownMultiplier = 1.0f;
	                }
	            }
	        }, duration);
	    }
	}

    
    private Tower findTowerAtPosition(float x, float y) {
        for (Actor actor : getStage().getActors()) {
            if (actor instanceof Tower) {
                Tower tower = (Tower) actor;
                if (tower.getBoundingRectangle().contains(x-getWidth()/2, y-getHeight()/2)) {
                    return tower;
                }
            }
        }
        return null;
    }
    
    public Rectangle getBoundingRectangle() {
        return new Rectangle(getX()-getWidth()/2, getY()-getHeight()/2, getWidth(), getHeight());
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
        if (Math.random() < 0.3) { // 30% 확률 성공
            for (Tower other : availableTowers) {
                if (other.towerGrade == this.towerGrade + 1) {
                    this.physicalAttack = other.physicalAttack;
                    this.magicAttack = other.magicAttack;
                    this.basePhysicalAttack = other.basePhysicalAttack;
                    this.baseMagicAttack = other.baseMagicAttack;
                    this.attackSpeed = other.attackSpeed;
                    this.attackRange = other.attackRange;
                    this.gridSize = other.gridSize;
                    this.attackCooldown = other.attackCooldown;
                    this.damageComponent = other.damageComponent;
                    this.name = other.name;
                    this.texture = other.texture;
                    this.towerGrade = other.towerGrade;
                    this.stage = other.stage;
                    this.team = other.team;
                    this.imagePath = other.imagePath;
                    this.attackImagePath =other.attackImagePath;
                    this.towerPortraitPath = other.towerPortraitPath;
                    this.attackAnimation = other.attackAnimation;
                    this.skill = other.skill;
                    return true;
                }
            }
        } else {
        	remove(); // 타워 삭제
        }
		return false;
    }
    
    private boolean isDragging = false;
    private Vector2 dragStartPos;
    

    private Tower mergeTowers(Tower baseTower) {
        Array<Tower> possibleUpgrades = stage.availableTowers;
        possibleUpgrades.shuffle();
        for (Tower newTower : possibleUpgrades) {
            if (newTower.towerGrade == baseTower.towerGrade + 1) {
                // 새 타워를 생성하여 기존 타워 위치에 소환
                Tower upgradedTower = new Tower(newTower);
                upgradedTower.setPosition(baseTower.getX(), baseTower.getY());
                upgradedTower.setTouchable(Touchable.enabled);
                upgradedTower.setSize(baseTower.getWidth(), baseTower.getHeight());
                
                getStage().addActor(upgradedTower); // 스테이지에 추가
                stage.towers.add(upgradedTower); // 타워 리스트에 추가
                stage.towers.removeValue(baseTower, true);
                stage.towers.removeValue(this, true);

                stage.towerInfoTable.setVisible(false);
                return upgradedTower;
            }
        }
        return null;
    }
    public void setTexture(String imagePath) {
        if (texture != null) {
            texture.dispose(); // 기존 텍스처 메모리 해제
        }

        Pixmap originalPixmap = new Pixmap(Gdx.files.internal(imagePath));
        Pixmap resizedPixmap = new Pixmap((int) (getWidth()), (int) (getHeight()), originalPixmap.getFormat());
        resizedPixmap.drawPixmap(originalPixmap, 
                                 0, 0, originalPixmap.getWidth(), originalPixmap.getHeight(), 
                                 0, 0, resizedPixmap.getWidth(), resizedPixmap.getHeight());

        texture = new Texture(resizedPixmap);
        resizedPixmap.dispose();
        originalPixmap.dispose();
    }
    
    private void setAttackAnimation(String spriteSheetPath) {
        Texture sheet = new Texture(Gdx.files.internal(spriteSheetPath));
        TextureRegion[][] tmpFrames = TextureRegion.split(sheet, 640, 640);
        Array<TextureRegion> frames = new Array<>();

        int rows = tmpFrames.length;    // 스프라이트 시트의 행 개수
        int cols = tmpFrames[0].length; // 각 행의 열 개수 (기본적으로 5)

        for (int row = 0; row < rows; row++) {
            for (int col = 0; col < cols; col++) {
                frames.add(tmpFrames[row][col]); // 모든 행과 열을 추가
            }
        }

        // 애니메이션이 attackCooldown 내에 끝나도록 프레임 지속 시간 조정
        float frameDuration = (1f / (float) attackSpeed) / (float) frames.size;

        attackAnimation = new Animation<>(frameDuration, frames);
        attackAnimation.setPlayMode(Animation.PlayMode.NORMAL);
    }

	 // 공격 시작 시 texture를 변경
	 public void attack(Enemy target) {
	     if (isAttacking) return; // 중복 실행 방지
	
	     isAttacking = true;
	     elapsedTime = 0;

	     // 🔹 첫 프레임을 저장
	     currentFrame = attackAnimation.getKeyFrame(0);
	 }

    // 업데이트 메서드 (적을 탐지하고 공격하는 로직 포함)
    public void update(float delta, Array<Enemy> enemies) {
        attackCooldown -= delta;

        if (attackCooldown <= 0) {
            attackCooldown = 1 / attackSpeed; // 공격 속도 기반 쿨타임 재설정

            // 범위 내에서 타겟 탐색
            Enemy target = findTarget(enemies,attackType);
            this.target = target;
            if (target != null) {
                attack(target); // 공격
            }
        }
        if (target != null) {
            skill.use(this, enemies);
            skill.update(delta);
        }
    }
    
    public void render(SpriteBatch batch, Texture guideTexture, Texture guideTexture2) {
        // 타워 등급에 따른 색상 정의
        Color gradeColor;
        switch (towerGrade) {
            case 1: gradeColor = Color.LIGHT_GRAY; break;  // 1등급: 회색
            case 2: gradeColor = Color.GREEN; break;       // 2등급: 초록색
            case 3: gradeColor = Color.BLUE; break;        // 3등급: 파란색
            case 4: gradeColor = Color.PURPLE; break;      // 4등급: 보라색
            case 5: gradeColor = Color.ORANGE; break;      // 5등급: 주황색
            default: gradeColor = Color.RED; break;        // 그 이상: 빨간색
        }
        
        // 원래 배치 색상 저장
        Color originalColor = batch.getColor().cpy();
    
        if (isAttacking) {
            elapsedTime += Gdx.graphics.getDeltaTime();
            currentFrame = attackAnimation.getKeyFrame(elapsedTime);  // 현재 프레임 업데이트
    
            // 마지막 프레임에 데미지 or 투사체 생성
            if (attackAnimation.isAnimationFinished(elapsedTime)) {
                if(target==null) {
                    isAttacking = false;
                    currentFrame = new TextureRegion(originalTexture);
                    return;
                }
                if (this.attackRange >= 4 * gridSize) {
                    // 원거리 공격 (투사체 발사)
                    Texture projectileTexture = new Texture(Gdx.files.internal("tower/projectile.png"));
                    Projectile projectile = new Projectile(projectileTexture, new Vector2(getX(), getY()), target, damageComponent, gridSize*0.5f, 1f/attackSpeed);
                    
                    getStage().addActor(projectile);
                    
                } else {
                    // 근거리 공격 (즉시 데미지)
                    target.addDamage(damageComponent);
                }
                isAttacking = false;
                currentFrame = new TextureRegion(originalTexture);
            }
        }
        else {
            currentFrame = new TextureRegion(originalTexture); // 기본 상태
        }
        
        // 텍스처를 그리드 중앙에 그리기
        float originX = getWidth() * 0.1f;
        float originY = getHeight() * 0.1f;
        
        // 중앙 정렬로 텍스처 그리기
        batch.draw(
            currentFrame,
            getX() + originX,     // 왼쪽 하단 X 좌표 계산
            getY() + originY,     // 왼쪽 하단 Y 좌표 계산
            originX, originY,     // 회전 원점
            getWidth(), getHeight(), // 크기
            1, 1,                 // 스케일
            0                     // 회전 각도
        );
        
        // 등급에 따른 색상 띠 그리기
        batch.setColor(gradeColor);
        
        // 띠의 높이는 타워 높이의 8%로 설정
        float barHeight = getHeight() * 0.08f;
        // 띠의 너비는 타워 너비의 80%로 설정
        float barWidth = getWidth() * 0.8f;
        // 띠를 타워의 아래쪽에 배치 (타워 높이의 5% 정도 위에)
        float barY = getY() + originY + getHeight() * 0.05f;
        // 띠를 타워의 중앙에 맞춰서 배치
        float barX = getX() + originX*2;
        
        // 등급 띠 그리기 (색상이 지정된 사각형)
        batch.draw(
            getWhitePixel(),
            barX,
            barY,
            barWidth,
            barHeight
        );
        
        // 원래 배치 색상으로 복원
        batch.setColor(originalColor);
    
        if (isDragging) {
            if(isMergable) {
                batch.draw(guideTexture2, dragStartPos.x-getWidth()/2,
                        dragStartPos.y-getHeight()/2);
            }
            else {
                batch.draw(guideTexture, dragStartPos.x-getWidth()/2,
                        dragStartPos.y-getHeight()/2);
            }
        }
    }
    
    // 단색 텍스처를 얻기 위한 메서드 (하얀색 1x1 픽셀)
    private static Texture whitePixel = null;
    private Texture getWhitePixel() {
        if (whitePixel == null) {
            Pixmap pixmap = new Pixmap(1, 1, Pixmap.Format.RGBA8888);
            pixmap.setColor(Color.WHITE);
            pixmap.fill();
            whitePixel = new Texture(pixmap);
            pixmap.dispose();
        }
        return whitePixel;
    }

    @Override
    public void draw(Batch batch, float parentAlpha) {
    	super.draw(batch, parentAlpha);
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


    public String getTeam() {
		return team;
	}

	public void setTeam(String team) {
		this.team = team;
	}

    public String getImagePath() {
		return imagePath;
	}

	public void setImagePath(String imagePath) {
		this.imagePath = imagePath;
	}


	public float getBasePhysicalAttack() {
		return basePhysicalAttack;
	}


	public void setBasePhysicalAttack(float basePhysicalAttack) {
		this.basePhysicalAttack = basePhysicalAttack;
	}


	public float getBaseMagicAttack() {
		return baseMagicAttack;
	}


	public void setBaseMagicAttack(float baseMagicAttack) {
		this.baseMagicAttack = baseMagicAttack;
	}


	
}
