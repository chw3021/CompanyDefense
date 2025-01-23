package io.github.chw3021.companydefense.enemy;

import java.util.ArrayList;
import java.util.List;

import com.badlogic.ashley.core.Entity;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.math.Vector2;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.component.EnemyComponent;
import io.github.chw3021.companydefense.component.HealthComponent;
import io.github.chw3021.companydefense.component.PathfindingComponent;
import io.github.chw3021.companydefense.component.TransformComponent;
import io.github.chw3021.companydefense.pathfinding.AStarPathfinding;
import io.github.chw3021.companydefense.stage.Wave;
public class Enemy extends Entity {
    private AStarPathfinding aStarPathfinding; // A* 경로 탐색
    private List<Vector2> path; // 적의 경로
    private int currentPathIndex; // 현재 경로 인덱스
    private Texture texture; // 적의 텍스처
    private TransformComponent transform; // 위치 및 이동 속도 관리
    private HealthComponent healthComponent;
    private DamageComponent damageComponent;
    private PathfindingComponent pathfinding;
    private EnemyComponent enemyComponent;
    private Wave wave;
    
    
    public Enemy(float startX, float startY, float health, float physicalDefense, float magicDefense, float moveSpeed,
                 String type, String image, Vector2 target, int mapWidth, int mapHeight, int gridSize) {
        // TransformComponent 사용
        transform = new TransformComponent();
        transform.setPosition(new Vector2(startX, startY));
        transform.setMoveSpeed(moveSpeed);

        // HealthComponent 추가
        healthComponent = new HealthComponent(health, physicalDefense, magicDefense);

        // EnemyComponent 추가
        enemyComponent = new EnemyComponent(type);

        // PathfindingComponent 추가
        pathfinding = new PathfindingComponent();
        pathfinding.setTarget(target);
        
        damageComponent = new DamageComponent(0, 0);

        this.add(transform);
        this.add(healthComponent);
        this.add(enemyComponent);
        this.add(pathfinding);
        this.add(damageComponent);

        // AStarPathfinding 객체 초기화
        this.aStarPathfinding = AStarPathfinding.getInstance(mapWidth, mapHeight, gridSize);
        this.path = new ArrayList<>();
        this.currentPathIndex = 0;
        
        // 텍스처 로드
        loadTexture(image);
    }

    // 텍스처 로드 메서드
    private void loadTexture(String path) {
        Pixmap originalPixmap = new Pixmap(Gdx.files.internal(path));

        // 텍스처 크기 조정 (예: 50x50)
        Pixmap resizedPixmap = new Pixmap(50, 50, originalPixmap.getFormat());
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
        
        path = aStarPathfinding.findPath((int)transform.getPosition().x, (int)transform.getPosition().y,
                (int)pathfinding.getTarget().x, (int)pathfinding.getTarget().y);

        
        currentPathIndex = 0; // 경로를 다시 시작
    }

    // 적이 경로를 따라 이동하는 메서드
    public void moveAlongPath() {
        if (path.isEmpty()) return;

        TransformComponent transform = this.getComponent(TransformComponent.class);

        // 현재 경로의 목표 지점까지 이동
        Vector2 target = path.get(currentPathIndex);
        if (transform.position.dst(target) < 5) { // 목표 지점에 가까워지면
            currentPathIndex++;
            if (currentPathIndex >= path.size()) {
                currentPathIndex = path.size() - 1; // 마지막 경로에 도달하면 멈춤
            	dispose();
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

    // 화면에 적을 그리기 위한 렌더링 메서드
    public void render(SpriteBatch batch) {
        batch.draw(texture, transform.position.x, transform.position.y);
    }

    // 리소스를 해제하는 메서드
    public void dispose() {
        if (texture != null) {
            texture.dispose(); // 텍스처 리소스 해제
        }
    	wave.removeEnemy(this);
    }
    public void addDamage(float physicalDamage, float magicDamage) {
        // 기존의 DamageComponent에 데미지 추가
        damageComponent.setPhysicalDamage(physicalDamage);
        damageComponent.setMagicDamage(magicDamage);
        if(getHealth()<=0) {
        	dispose();
        }
        System.out.println(this +" "+ getHealth());
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
		return "Enemy [transform=" + transform + ", healthComponent=" + healthComponent + ", damageComponent="
				+ damageComponent + ", wave=" + wave + "]";
	}
}
