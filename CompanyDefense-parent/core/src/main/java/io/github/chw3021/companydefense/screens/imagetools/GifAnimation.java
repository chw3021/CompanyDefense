package io.github.chw3021.companydefense.screens.imagetools;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.g2d.Animation;
import com.badlogic.gdx.graphics.g2d.Batch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.scenes.scene2d.Actor;

public class GifAnimation extends Actor {
    private Animation<TextureRegion> animation;
    private float elapsedTime = 0f;

    public GifAnimation(String gifFilePath, float width, float height) {
        animation = GifDecoder.loadGIFAnimation(Animation.PlayMode.LOOP, Gdx.files.internal(gifFilePath).read());
        setSize(width, height); // Actor 크기 설정
    }

    @Override
    public void act(float delta) {
        super.act(delta);
        elapsedTime += delta;
    }

    @Override
    public void draw(Batch batch, float parentAlpha) {
        batch.draw(animation.getKeyFrame(elapsedTime), getX(), getY(), getWidth(), getHeight());
    }
}
