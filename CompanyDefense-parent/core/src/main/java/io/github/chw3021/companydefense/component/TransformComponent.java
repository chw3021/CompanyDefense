package io.github.chw3021.companydefense.component;

import com.badlogic.ashley.core.Component;
import com.badlogic.gdx.math.Vector2;

public class TransformComponent implements Component {
    public Vector2 position = new Vector2();
    public Vector2 velocity = new Vector2();
    public float moveSpeed;
}