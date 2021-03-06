﻿$(function() {
    $("#submitProject").click(submitProjectClicked);
    $("#submitReleases").click(submitReleasesClicked);
    $(".work-box").click(loadProject);
});

function loadProject(e) {
    e.preventDefault();
    $("#repoInput").val($(this).attr("data-repo"));
    $("#projectInput").val($(this).attr("data-project"));
    $("#submitProject").click();
    return false;
}

function submitReleasesClicked(e) {
    e.preventDefault();

    var tag1 = $("#releaseDropdown1").val();
    var tag2 = $("#releaseDropdown2").val();

    if (tag1 && tag2) {
        getDependencyComparison(tag1, tag2);
    }
    if (tag1 && !tag2) {
        getDependencies(tag1);
    }
    if (!tag1 && tag2) {
        getDependencies(tag2);
    }
    $("#legend-for-double-tree").show();
}

function getDependencies(tag) {
    $("#dependencyArea").html("");
    $("#preloader_container").show();
    GetDependenciesOfOneReleaseRequest(getRepo(), getProject(), tag).done(function (response) {
        var json = "{}";
        json = JSON.parse(response.d);
        if (json.ERROR) {
            alert(json.ERROR);
        } else {
            renderDependencies(json[tag]);
        }
    });
}

function getDependencyComparison(tag1, tag2) {
    var oldJson = "{}";
    var newJson = "{}";
    $("#dependencyArea").html("");
    $("#preloader_container").show();
    GetDependenciesOfOneReleaseRequest(getRepo(), getProject(), tag1).done(function (response) {
        oldJson = JSON.parse(response.d);
        if (oldJson.ERROR) {
            alert(oldJson.ERROR);
            return;
        }
        GetDependenciesOfOneReleaseRequest(getRepo(), getProject(), tag2).done(function (response) {
            newJson = JSON.parse(response.d);
            if (newJson.ERROR) {
                alert(newJson.ERROR);
                return;
            }
            renderDependencyComparison(oldJson[tag1], newJson[tag2]);
        });
    });
}

function submitProjectClicked(e) {

    e.preventDefault();//revent form submit

    if (validateSubmittedProject()) {
        var repo = $("#repoInput").val() || $("#repoInput").attr("placeholder");
        var project = $("#projectInput").val() || $("#projectInput").attr("placeholder");
        //store for other components to access the currently picked repo and project
        $("#repoInput").attr("data-selected", repo);
        $("#projectInput").attr("data-selected", project);
        
        GetReleasesRequest(repo, project).done(function (response) {
            if (response.d.length) {
                fillReleaseDropdowns(response.d);
                scrollTo($("#releasePickBarrier"));
                $("#releasePicker").slideDown(1000);
            } else {
                alert("No tagged releases could be found for this project or the github api limit has been exceeded");
            }
        });
    }
}

function getRepo() {
    return $("#repoInput").attr("data-selected");
}

function getProject() {
    return $("#projectInput").attr("data-selected");
}

function scrollTo(elem) {
    $('html, body').animate({
        scrollTop: $(elem).offset().top
    }, 1000);
}

function validateSubmittedProject() {
    return true; //empty is allowed, with default values
}

function GetReleasesRequest(repo, project) {
    return $.ajax(
        "default.aspx/Releases",
        {
            data: JSON.stringify({ repo: repo, projectName: project }),
            type: "POST",
            dataType: "json",
            contentType: "application/json",
            error: function() {
                failureWarning("Something went wrong while fetching the releases of the chosen project.");
            }
        });
}

function GetDependenciesOfOneReleaseRequest(repo, project, tagName) {
    return $.ajax(
        "default.aspx/Dependencies",
        {
            data: JSON.stringify({ repo: repo, projectName: project, tagName: tagName }),
            type: "POST",
            dataType: "json",
            contentType: "application/json",
            error: function () {
                failureWarning("Something went wrong while fetching the dependencies of the release with tagname " + tagName);
            }
        });
}

function failureWarning(message) {
    alert(message);
}

function fillReleaseDropdowns(releases) {
    $("#releaseDropdown1,#releaseDropdown2").html("");
    $("#releaseDropdown1,#releaseDropdown2").append("<option value=''>No release selected...</option>");
    releases.forEach(r => $("#releaseDropdown1,#releaseDropdown2").append("<option value='" + r.Release.TagName + "'>" + r.Release.Name + "(" + r.Release.TagName + ") "+ (r.IsDownloaded ? "(downloaded)" : "") + "</option>"));
    if (releases.length > 0) {
        $($("#releaseDropdown2 option")[1]).attr("selected", "selected"); //"no release selected" is first
    }
    if (releases.length > 1) {
        $($("#releaseDropdown1 option")[2]).attr("selected", "selected"); //"no release selected" is first
    }
}