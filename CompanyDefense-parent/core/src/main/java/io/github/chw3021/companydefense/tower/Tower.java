package io.github.chw3021.companydefense.tower;

import com.badlogic.ashley.core.Entity;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.component.TransformComponent;
import io.github.chw3021.companydefense.enemy.Enemy;
public class Tower extends Entity {
    private Texture texture;
    private TransformComponent transform;
    
    // 새로운 속성들
    private float physicalAttack;
    private float magicAttack;
    private float attackSpeed;
    private float attackRange;

    public Tower(float startX, float startY, float physicalAttack, float magicAttack, float attackSpeed, 
                 float attackRange, String path) {
    	// TransformComponent 사용
        transform = new TransformComponent();
        transform.position.set(startX, startY);
        
        // 기본 공격력과 공격 속도 설정
        this.physicalAttack = physicalAttack;
        this.magicAttack = magicAttack;
        this.attackSpeed = attackSpeed;
        this.attackRange = attackRange;
        
        // 텍스처 로드
        Pixmap originalPixmap = new Pixmap(Gdx.files.internal(path));
        
        // 새 크기 설정 (예: 50x50)
        Pixmap resizedPixmap = new Pixmap(50, 50, originalPixmap.getFormat());
        resizedPixmap.drawPixmap(originalPixmap,
                                 0, 0, originalPixmap.getWidth(), originalPixmap.getHeight(),
                                 0, 0, resizedPixmap.getWidth(), resizedPixmap.getHeight());
        
        texture = new Texture(resizedPixmap); 
        
        this.add(transform);
    }

    public void setPosition(Vector2 position) {
        this.transform.position.set(position);
    }

    public Vector2 getPosition() {
        return transform.position;
    }

    public void setVelocity(Vector2 velocity) {
        this.transform.velocity.set(velocity);
    }

    public Vector2 getVelocity() {
        return transform.velocity;
    }

    // 공격 범위 내의 적을 찾는 메서드
    private Enemy findTarget(Array<Enemy> enemies, String attackType) {
        Enemy target = null;

        for (Enemy enemy : enemies) {
            // 적과 타워 사이의 거리 계산
            float distance = transform.position.dst(enemy.getPosition());

            // 사정거리 내에 있는지 확인
            if (distance <= attackRange) {
                if (attackType.equals("nearest")) {
                    if (target == null || distance < transform.position.dst(target.getPosition())) {
                        target = enemy;  // 가장 가까운 적
                    }
                } else if (attackType.equals("farthest")) {
                    if (target == null || distance > transform.position.dst(target.getPosition())) {
                        target = enemy;  // 가장 멀리 있는 적
                    }
                } else if (attackType.equals("highestHealth")) {
                    if (target == null || enemy.getHealth() > target.getHealth()) {
                        target = enemy;  // 최대 체력을 가진 적
                    }
                }
            }
        }

        return target;
    }

    // 공격 메서드: 공격 대상을 찾아서 공격 처리
    public void attack(Array<Enemy> enemies, String attackType) {
        Enemy target = findTarget(enemies, attackType);  // 공격 대상을 찾음

        if (target != null) {
            // 공격 관련 로직 구현 (예: 물리 공격, 마법 공격 등)
            target.takeDamage(physicalAttack, magicAttack);  // 적에게 피해를 주는 메서드
        }
    }

    public void update(float delta, Array<Enemy> enemies, String attackType) {
        // 공격 주기 등을 고려하여 공격을 호출
        attack(enemies, attackType);

        // 위치 업데이트
        transform.position.x += transform.velocity.x * delta;  // 경로를 따라 이동
    }

    public void render(SpriteBatch batch) {
        batch.draw(texture, transform.position.x, transform.position.y);
    }

    
    public void dispose() {
        texture.dispose();
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
}
