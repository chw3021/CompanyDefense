package io.github.chw3021.companydefense.component;

import com.badlogic.ashley.core.Component;
import com.badlogic.gdx.math.Vector2;

public class TransformComponent implements Component {
    public Vector2 position = new Vector2();
    public float moveSpeed;
	public Vector2 getPosition() {
		return position;
	}
	public void setPosition(Vector2 position) {
		this.position = position;
	}
	public float getMoveSpeed() {
		return moveSpeed;
	}
	public void setMoveSpeed(float moveSpeed) {
		this.moveSpeed = moveSpeed;
	}
}