package io.github.chw3021.companydefense.screens.imagetools;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.Batch;
import com.badlogic.gdx.graphics.g2d.GlyphLayout;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.ui.ImageButton;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Label.LabelStyle;
import com.badlogic.gdx.scenes.scene2d.utils.BaseDrawable;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.scenes.scene2d.utils.Drawable;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;

public class Commons {

    public static ImageButton createImageButton(String upImagePath, String downImagePath, ClickListener listener) {
        // 텍스처 로드
        Texture upTexture = new Texture(Gdx.files.internal(upImagePath));
        Texture downTexture = new Texture(Gdx.files.internal(downImagePath));

        // TextureRegionDrawable로 버튼 이미지 설정
        TextureRegionDrawable upDrawable = new TextureRegionDrawable(new TextureRegion(upTexture));
        TextureRegionDrawable downDrawable = new TextureRegionDrawable(new TextureRegion(downTexture));

        // ImageButtonStyle 설정
        ImageButton.ImageButtonStyle style = new ImageButton.ImageButtonStyle();
        style.up = upDrawable;
        style.down = downDrawable;
        style.disabled = downDrawable;


        // ImageButton 생성
        ImageButton button = new ImageButton(style);
        button.addListener(listener); // 클릭 리스너 추가

        return button;
    }

    /** 네비게이션 버튼 생성 */
    public static ImageButton createImageButton(String upImagePath, String downImagePath, Runnable onClick) {
    	String downPath = "menu/accept.png";
        ImageButton button = Commons.createImageButton(upImagePath, downImagePath);
        button.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                onClick.run();
            }
        });
        return button;
    }

    public static ImageButton createImageButton(String upImagePath, String downImagePath) {
        // 텍스처 로드
        Texture upTexture = new Texture(Gdx.files.internal(upImagePath));
        Texture downTexture = new Texture(Gdx.files.internal(downImagePath));

        // TextureRegionDrawable로 버튼 이미지 설정
        TextureRegionDrawable upDrawable = new TextureRegionDrawable(new TextureRegion(upTexture));
        TextureRegionDrawable downDrawable = new TextureRegionDrawable(new TextureRegion(downTexture));

        // ImageButtonStyle 설정
        ImageButton.ImageButtonStyle style = new ImageButton.ImageButtonStyle();
        style.up = upDrawable;
        style.down = downDrawable;
        style.disabled = downDrawable;


        // ImageButton 생성
        ImageButton button = new ImageButton(style);

        return button;
    }
    public static LabelStyle createLabelStyleWithBackground(Label label, Skin skin) {
        LabelStyle labelStyle = new LabelStyle();
        labelStyle.font = skin.getFont("default");
        labelStyle.fontColor = Color.WHITE;
        labelStyle.background = createBackground(label);
        return labelStyle;
    }

    public static Drawable createBackground(Label label) {
	    Pixmap labelColor = new Pixmap(1, 1, Pixmap.Format.RGBA8888);
	    Color color = new Color(Color.LIGHT_GRAY);
	    color.a = 0.35f;
	    labelColor.setColor(color);
	    labelColor.fill();
	
	    Texture texture = new Texture(labelColor);
	
	    return new BaseDrawable() {
	
	        @Override
	        public void draw(Batch batch, float x, float y, float width, float height) {
	            GlyphLayout layout = label.getGlyphLayout();
	            x = label.getX();
	            y = label.getY();
	            batch.draw(texture, x, y, layout.width, layout.height);
	        }
	    };
	}
}
