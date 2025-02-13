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

        Array<TextureRegion> frames = new Array<>();

        // 이미지 크기 확인
        int sheetWidth = sheet.getWidth();
        int sheetHeight = sheet.getHeight();

        // 스프라이트 시트인지 단일 이미지인지 판별
        if (sheetWidth < frameWidth || sheetHeight < frameHeight) {
            // 🔹 단일 이미지라면 그대로 추가
            frames.add(new TextureRegion(sheet));
        } else {
            // 🔹 스프라이트 시트라면 프레임 단위로 나누기
            TextureRegion[][] tmpFrames = TextureRegion.split(sheet, frameWidth, frameHeight);
            int cols = tmpFrames[0].length; // 각 행의 열 개수
            int rows = tmpFrames.length;    // 총 행 개수

            // 프레임 개수 제한
            if (cols < 5) {
                frames.add(tmpFrames[0][0]); // 첫 번째 프레임만 추가
            } else {
                rows = Math.min(rows, 5); // 최대 5개 행까지만 사용

                for (int row = 0; row < rows; row++) {
                    for (int col = 0; col < cols; col++) {
                        frames.add(tmpFrames[row][col]); // 모든 행과 열을 추가
                    }
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


