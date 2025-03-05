package io.github.chw3021.companydefense.dto;

public class HobbyDto {
    private String hobbyId;
    private String hobbyName;
    private String hobbyDescription;
    private String hobbyImagePath;

    public HobbyDto() {
    }

    public HobbyDto(String hobbyId, String hobbyName, String hobbyDescription, String hobbyImagePath) {
        this.hobbyId = hobbyId;
        this.hobbyName = hobbyName;
        this.hobbyDescription = hobbyDescription;
        this.hobbyImagePath = hobbyImagePath;
    }

    public String getHobbyId() {
        return hobbyId;
    }

    public void setHobbyId(String hobbyId) {
        this.hobbyId = hobbyId;
    }

    public String getHobbyName() {
        return hobbyName;
    }

    public void setHobbyName(String hobbyName) {
        this.hobbyName = hobbyName;
    }

    public String getHobbyDescription() {
        return hobbyDescription;
    }

    public void setHobbyDescription(String hobbyDescription) {
        this.hobbyDescription = hobbyDescription;
    }

    public String getHobbyImagePath() {
        return hobbyImagePath;
    }

    public void setHobbyImagePath(String hobbyImagePath) {
        this.hobbyImagePath = hobbyImagePath;
    }
}