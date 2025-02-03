package io.github.chw3021.companydefense.screens.imagetools;

import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.scenes.scene2d.ui.Image;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;

public class RotatingImage extends Image {
    private float rotationSpeed;

    public RotatingImage(Texture texture, float rotationSpeed) {
        super(new TextureRegionDrawable(new TextureRegion(texture)));
        this.rotationSpeed = rotationSpeed;

        // 크기를 Texture 크기와 동일하게 설정 (혹은 비율에 맞게 조정)
        setSize(texture.getWidth(), texture.getHeight());

        // 중심축을 정확하게 설정
        setOrigin(getWidth() / 2f, getHeight() / 2f);
    }

    @Override
    public void act(float delta) {
        super.act(delta);
        setRotation(getRotation() + rotationSpeed * delta);
    }
}
