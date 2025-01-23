package io.github.chw3021.companydefense.obstacle;

import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.math.Vector2;
public class Obstacle { 
    private Texture texture;
    private Vector2 position;

    // 생성자
    public Obstacle(float startX, float startY, Pixmap originalPixmap, int width, int height) {
        position = new Vector2(startX, startY);
        loadTexture(originalPixmap, width, height);
    }

    // Texture 로드 메서드 (재사용 가능)
    private void loadTexture(Pixmap originalPixmap, int width, int height) {
        Pixmap resizedPixmap = new Pixmap(width, height, originalPixmap.getFormat());
        resizedPixmap.drawPixmap(originalPixmap,
                0, 0, originalPixmap.getWidth(), originalPixmap.getHeight(),
                0, 0, width, height);
        
        texture = new Texture(resizedPixmap);
        resizedPixmap.dispose();
    }

    // 위치 관련 메서드
    public Vector2 getPosition() {
        return position;
    }

    public void setPosition(Vector2 position) {
        this.position = position;
    }

    // X, Y 위치를 각각 반환하는 메서드 추가
    public float getX() {
        return position.x;
    }

    public float getY() {
        return position.y;
    }

    // 렌더링
    public void render(SpriteBatch batch) {
        batch.draw(texture, position.x, position.y);
    }

    // 리소스 해제
    public void dispose() {
        texture.dispose();
    }
}
