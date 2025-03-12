package io.github.chw3021.companydefense.enemy;

import java.util.ArrayList;
import java.util.List;

import com.badlogic.ashley.core.Entity;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.TimeUtils;
import com.badlogic.gdx.utils.Timer;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.component.HealthComponent;
import io.github.chw3021.companydefense.component.PathfindingComponent;
import io.github.chw3021.companydefense.component.TransformComponent;
import io.github.chw3021.companydefense.pathfinding.AStarPathfinding;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.stage.Wave;


public class Enemy extends Entity {
    private AStarPathfinding aStarPathfinding; // A* 경로 탐색
    private List<Vector2> path; // 적의 경로
    private int currentPathIndex; // 현재 경로 인덱스
    private Texture texture; // 적의 텍스처
    private TransformComponent transform; // 위치 및 이동 속도 관리
    private HealthComponent healthComponent;
    private PathfindingComponent pathfinding;
    private String type;
    private Wave wave;
    private StageParent stage;
    private int size;
    private float[][] map;

    private static final float HEALTH_BAR_HEIGHT = 5f; // 체력바 높이
    private static final float HEALTH_BAR_MARGIN = 3f; // 적과 체력바 간 거리
    
    public Enemy(float startX, float startY, float health, float physicalDefense, float magicDefense, float moveSpeed,
                 String type, String image, Vector2 target, StageParent stage, float[][] map) {
        // TransformComponent 사용
        transform = new TransformComponent();
        transform.setPosition(new Vector2(startX, startY));
        transform.setMoveSpeed(moveSpeed);

        // HealthComponent 추가
        healthComponent = new HealthComponent(health, physicalDefense, magicDefense);

        this.type = type;

        // PathfindingComponent 추가
        pathfinding = new PathfindingComponent();
        pathfinding.setTarget(target);
        

        this.add(transform);
        this.add(healthComponent);
        this.add(pathfinding);
        this.stage = stage;

        // AStarPathfinding 객체 초기화
        this.aStarPathfinding = AStarPathfinding.getInstance(stage.mapWidth, stage.mapHeight, stage.gridSize);
        this.path = new ArrayList<>();
        this.currentPathIndex = 0;
        
        
        size = stage.gridSize;
        this.map = map;
        
        // 텍스처 로드
        loadTexture(image);
    }

    // 텍스처 로드 메서드
    private void loadTexture(String path) {
        Pixmap originalPixmap = new Pixmap(Gdx.files.internal(path));

        Pixmap resizedPixmap = new Pixmap(size/2, size/2, originalPixmap.getFormat());
        resizedPixmap.drawPixmap(originalPixmap,
                0, 0, originalPixmap.getWidth(), originalPixmap.getHeight(),
                0, 0, resizedPixmap.getWidth(), resizedPixmap.getHeight());

        texture = new Texture(resizedPixmap); // 텍스처로 변환
        originalPixmap.dispose();
        resizedPixmap.dispose();
    }

    // 경로를 찾고 이동하는 메서드
    public void updatePath() {
        // AStarPathfinding의 findPath 메서드를 사용하여 경로 계산
        
        path = aStarPathfinding.findPath(map);

        
        currentPathIndex = 0; // 경로를 다시 시작
    }

    private boolean isStunned = false; // 기절 상태 여부
    private float stunEndTime = 0; // 기절이 끝나는 시간

    public void stun(float duration) {
        isStunned = true;
        stunEndTime = TimeUtils.nanoTime() + (long) (duration * 1_000_000_000L);
    }

    private boolean isStunOver() {
        return TimeUtils.nanoTime() >= stunEndTime;
    }

    
    // 적이 경로를 따라 이동하는 메서드
    public void moveAlongPath() {
    	
        if (isStunned && !isStunOver()) return; // 기절 중이면 이동 불가
        isStunned = false; // 기절이 끝났으면 풀기
        
        if (path.isEmpty()) return;


        // 현재 경로의 목표 지점까지 이동
        Vector2 target = path.get(currentPathIndex);
        if (transform.position.dst(target) < 5) { // 목표 지점에 가까워지면
            currentPathIndex++;
            if (currentPathIndex >= path.size()) {
                currentPathIndex = path.size() - 1; // 마지막 경로에 도달하면 멈춤
            	dispose();
            	if(type.equals("boss")) {
                	stage.setLife(0);
            	}
            	else {
                	stage.setLife(stage.getLife()-1);
            	}
            }
        } else {
            // 목표 지점으로 이동
            Vector2 direction = target.cpy().sub(transform.position).nor();
            transform.position.add(direction.scl(transform.moveSpeed * Gdx.graphics.getDeltaTime()));
        }
    }

    // 게임 루프에서 호출할 메서드 (매 프레임마다 경로를 따라 이동)
    public void update() {
        if (path.isEmpty()) {
            updatePath(); // 경로가 없으면 경로 다시 계산
        } else {
            moveAlongPath(); // 경로를 따라 이동
        }
    }

    public boolean isAtTarget(Vector2 target) {
        return transform.position.dst(target) < 5.0f;  // 목표 지점에 가까워지면 true
    }

    public void renderHealthBar(ShapeRenderer shapeRenderer) {

        float barWidth = texture.getWidth();
        float barX = transform.position.x + texture.getWidth() / 2f; 
        float barY = transform.position.y + texture.getHeight() + HEALTH_BAR_MARGIN; // 적 위에 배치

        float healthRatio = healthComponent.health / healthComponent.maxHealth;
        float redBarWidth = barWidth * healthRatio; // 남은 체력 비율만큼 빨간색으로 표시

        // 검은색 배경
        shapeRenderer.setColor(Color.BLACK);
        shapeRenderer.rect(barX, barY, barWidth, HEALTH_BAR_HEIGHT);

        // 빨간색 체력 부분
        shapeRenderer.setColor(Color.RED);
        shapeRenderer.rect(barX, barY, redBarWidth, HEALTH_BAR_HEIGHT);

    }

    // 화면에 적을 그리기 위한 렌더링 메서드
    public void render(SpriteBatch batch) {
        float textureX = transform.position.x + texture.getWidth() / 2f; // 텍스처 중심으로 x 조정
        float textureY = transform.position.y + texture.getHeight() / 2f; // 텍스처 중심으로 y 조정
        batch.draw(texture, textureX, textureY); // 조정된 좌표로 그리기
    }

    // 리소스를 해제하는 메서드
    public void dispose() {
        if (texture != null) {
            texture.dispose(); // 텍스처 리소스 해제
        }
    	wave.removeEnemy(this);
    	stage.getActiveEnemies().removeValue(this, true);
    	stage.setCurrency(stage.getCurrency()+5);
    }
    
    public void addDamage(DamageComponent damageComponent) {
        healthComponent.damage(damageComponent);
    	if(getHealth()<=0) {
        	dispose();
        }
    }

    public void reduceDefense(float physicalReduction, float magicReduction, float duration) {
        healthComponent.physicalDefense -= physicalReduction;
    	healthComponent.magicDefense -= magicReduction;

        if (healthComponent.physicalDefense < 0) healthComponent.physicalDefense = 0;
        if (healthComponent.magicDefense < 0) healthComponent.magicDefense = 0;

        // 일정 시간 후 방어력 복구 (스케줄링)
        Timer.schedule(new Timer.Task() {
            @Override
            public void run() {
            	healthComponent.physicalDefense += physicalReduction;
            	healthComponent.magicDefense += magicReduction;
            }
        }, duration);
    }
    
    
    public void setWave(Wave wave) {
    	this.wave = wave;
    }
    
    public float getHealth() {
    	return healthComponent.health;
    }

	public Vector2 getPosition() {
		
		return transform.position;
	}

	@Override
	public String toString() {
		return "Enemy ["+  "healthComponent=" + healthComponent +  ", wave=" + wave + "]";
	}
}
