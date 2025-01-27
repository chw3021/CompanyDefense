package io.github.chw3021.companydefense.screens;

import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.scenes.scene2d.ui.Image;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;

public class RotatingImage extends Image {
    private float rotationSpeed;

    public RotatingImage(Texture texture, float rotationSpeed) {
        super(new TextureRegionDrawable(new TextureRegion(texture)));
        this.rotationSpeed = rotationSpeed; // 회전 속도 (도/초)
    }

    @Override
    public void act(float delta) {
        super.act(delta);
        // 현재 회전 값에 속도를 더함
        setRotation(getRotation() + rotationSpeed * delta);
    }
}
