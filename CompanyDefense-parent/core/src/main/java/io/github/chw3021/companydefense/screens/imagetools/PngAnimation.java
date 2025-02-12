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
        int cols = tmpFrames[0].length; // 각 행의 열 개수 (기본적으로 5)
        if(cols<5) {
            frames.add(tmpFrames[0][0]);
        }
        else {
            
            int rows = tmpFrames.length>1 ? tmpFrames.length-1 : 1;    // 스프라이트 시트의 행 개수

            for (int row = 0; row < rows; row++) {
                for (int col = 0; col < cols; col++) {
                    frames.add(tmpFrames[row][col]); // 모든 행과 열을 추가
                }
            }
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
    	batch.setColor(1, 1, 1, 1);
        batch.draw(animation.getKeyFrame(elapsedTime), getX(), getY(), getWidth(), getHeight());
    }
}

