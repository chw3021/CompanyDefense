package io.github.chw3021.companydefense.screens.imagetools;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.Animation;
import com.badlogic.gdx.graphics.g2d.Batch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.scenes.scene2d.Actor;
import com.badlogic.gdx.utils.Array;

public class PngAnimation extends Actor {
    private Animation<TextureRegion> animation;
    private float elapsedTime = 0f;
    private float frameWidth, frameHeight;

    public PngAnimation(float frameDuration, String spriteSheetPath, int frameWidth, int frameHeight, boolean looping) {
        Texture sheet = new Texture(Gdx.files.internal(spriteSheetPath));
        this.frameWidth = frameWidth;
        this.frameHeight = frameHeight;

        // 스프라이트 시트에서 프레임을 올바르게 잘라서 로드
        TextureRegion[][] tmpFrames = TextureRegion.split(sheet, frameWidth, frameHeight);
        Array<TextureRegion> frames = new Array<>();

        // 첫 번째 행의 5개 프레임만 가져옴
        for (int i = 0; i < 5; i++) {
            frames.add(tmpFrames[0][i]);
        }

        animation = new Animation<>(frameDuration, frames);
        if (looping) animation.setPlayMode(Animation.PlayMode.LOOP);
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

