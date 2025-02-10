package io.github.chw3021.companydefense.tower;

import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.Batch;
import com.badlogic.gdx.math.Rectangle;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.scenes.scene2d.Actor;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.enemy.Enemy;
import com.badlogic.gdx.scenes.scene2d.actions.Actions;

public class Projectile extends Actor {
    private Vector2 position;
    private Vector2 velocity;
    private Texture texture;
    private Enemy target;
    private float speed = 800f; // 속도 조정 가능
    private DamageComponent damage;
    private float size;
    private float elapsedTime = 0f;
    private float maxLifetime; // 1초 후 자동 삭제

    public Projectile(Texture texture, Vector2 startPosition, Enemy target, DamageComponent damage, float size, float maxLifetime) {
        this.texture = texture;
        this.position = new Vector2(startPosition);
        this.target = target;
        this.damage = damage;
        this.size = size;
        this.maxLifetime = maxLifetime;

        setBounds(position.x, position.y, size, size);

        // 1초 후 강제 삭제 및 피해 적용
        addAction(Actions.sequence(
            Actions.delay(this.maxLifetime),
            Actions.run(() -> {
                if (target != null) {
                    target.addDamage(damage);
                }
                remove();
            })
        ));
    }

    @Override
    public void act(float delta) {
        super.act(delta);

        // 타겟을 계속 추적하도록 방향 갱신
        if (target != null) {
            Vector2 direction = new Vector2(target.getPosition()).sub(position).nor();
            velocity = direction.scl(speed);
        }

        // 위치 갱신
        position.add(velocity.x * delta, velocity.y * delta);
        setPosition(position.x, position.y);

        // 타겟과의 거리 계산 (충돌 감지)
        if (target != null && position.dst(target.getPosition()) < 50f) {
            target.addDamage(damage);
            remove();
        }
    }

    @Override
    public void draw(Batch batch, float parentAlpha) {
    	batch.setColor(1, 1, 1, 1);
        batch.draw(texture, getX(), getY(), size, size);
    }
}
