package io.github.chw3021.companydefense.dto;

public class HobbyOwnershipDto {
    private String hobbyId;   // 취미의 ID
    private int hobbyLevel;   // 취미의 레벨

    public HobbyOwnershipDto() {
    }

    public HobbyOwnershipDto(String hobbyId, int hobbyLevel) {
        this.hobbyId = hobbyId;
        this.hobbyLevel = hobbyLevel;
    }

    public String getHobbyId() {
        return hobbyId;
    }

    public void setHobbyId(String hobbyId) {
        this.hobbyId = hobbyId;
    }

    public int getHobbyLevel() {
        return hobbyLevel;
    }

    public void setHobbyLevel(int hobbyLevel) {
        this.hobbyLevel = hobbyLevel;
    }
}