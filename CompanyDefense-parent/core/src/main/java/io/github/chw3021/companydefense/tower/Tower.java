package io.github.chw3021.companydefense.tower;

import com.badlogic.ashley.core.Entity;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.component.HealthComponent;
import io.github.chw3021.companydefense.component.TransformComponent;
import io.github.chw3021.companydefense.enemy.Enemy;


public class Tower extends Entity {
    private Texture texture;
    private TransformComponent transform;
    private int level;
    private String id;
    
    
    private String name;
    private float physicalAttack;
    private float magicAttack;
    private float attackSpeed;
    private float attackRange;
    private float attackCooldown; // 다음 공격까지 남은 시간
    private String attackType = "closest";
    private DamageComponent damageComponent;

    public Tower(float startX, float startY, float physicalAttack, float magicAttack, float attackSpeed, 
                 float attackRange, String path, String name, String attackType) {
    	// TransformComponent 사용
        transform = new TransformComponent();
        transform.position.set(startX, startY);
        
        // 기본 공격력과 공격 속도 설정
        this.physicalAttack = physicalAttack;
        this.magicAttack = magicAttack;
        this.attackSpeed = attackSpeed;
        this.attackRange = attackRange;
        this.attackCooldown = 0; // 초기화
        this.name = name; // 초기화
        damageComponent = new DamageComponent(physicalAttack, magicAttack);
        
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


    public Tower(Tower other) {
    	this.transform = new TransformComponent();
        this.transform.position.set(other.transform.position);
        this.physicalAttack = other.physicalAttack;
        this.magicAttack = other.magicAttack;
        this.attackSpeed = other.attackSpeed;
        this.attackRange = other.attackRange;
        this.attackCooldown = other.attackCooldown;
        this.damageComponent = other.damageComponent;
        this.name = other.name;
        this.texture = other.texture;
        this.add(transform);
        // 필요한 필드를 추가적으로 복사
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
            float distance = transform.position.dst(enemyPos);

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

    public void render(SpriteBatch batch) {
        batch.draw(texture, transform.position.x, transform.position.y);
    }

    
    public void dispose() {
        texture.dispose();
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
