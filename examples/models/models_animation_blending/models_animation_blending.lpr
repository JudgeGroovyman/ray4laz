program models_animation_blending;

{$mode objfpc}{$H+}

uses CocoaAll,
    raylib, rlgl, raygui, sysutils;

const
    screenWidth = 800;
    screenHeight = 450;

    {$IFDEF PLATFORM_DESKTOP}
    GLSL_VERSION = 330;
    {$ELSE}
    GLSL_VERSION = 100;
    {$ENDIF}

type
    TAnimNameArray = array[0..63] of PChar;
    PAnimNameArray = ^TAnimNameArray;

var
    camera: TCamera3D;
    model: TModel;
    position: TVector3;
    skinningShader: TShader;
    anims: PModelAnimation;
    animCount: Integer;
    currentAnimPlaying: Integer;
    nextAnimToPlay: Integer;
    animTransition: Boolean;
    animIndex0, animIndex1: Integer;
    animCurrentFrame0, animCurrentFrame1: Single;
    animFrameSpeed0, animFrameSpeed1: Single;
    animBlendFactor: Single;
    animBlendTime: Single;
    animBlendTimeCounter: Single;
    animPause: Boolean;
    animNames: array[0..63] of PChar;
    dropdownEditMode0, dropdownEditMode1: Boolean;
    animFrameProgress0, animFrameProgress1: Single;
    animBlendProgress: Single;
    i: Integer;
    tempStr: array[0..255] of Char;

begin
    // Initialization
    InitWindow(screenWidth, screenHeight, 'raylib [models] example - animation blending');

    // Define the camera to look into our 3d world
    camera.position := Vector3Create(6.0, 6.0, 6.0);
    camera.target := Vector3Create(0.0, 2.0, 0.0);
    camera.up := Vector3Create(0.0, 1.0, 0.0);
    camera.fovy := 45.0;
    camera.projection := CAMERA_PERSPECTIVE;

    // Load model
    model := LoadModel('resources/models/gltf/robot.glb');
    position := Vector3Create(0.0, 0.0, 0.0);

    // Load skinning shader
    skinningShader := LoadShader(
        TextFormat('resources/shaders/glsl%i/skinning.vs', GLSL_VERSION),
        TextFormat('resources/shaders/glsl%i/skinning.fs', GLSL_VERSION)
    );

    // Load model animations
    animCount := 0;
    anims := LoadModelAnimations('resources/models/gltf/robot.glb', @animCount);

    // Animation playing variables
    currentAnimPlaying := 0;
    nextAnimToPlay := 1;
    animTransition := False;

    animIndex0 := 10;
    animCurrentFrame0 := 0.0;
    animFrameSpeed0 := 0.5;
    animIndex1 := 6;
    animCurrentFrame1 := 0.0;
    animFrameSpeed1 := 0.5;

    animBlendFactor := 0.0;
    animBlendTime := 2.0;
    animBlendTimeCounter := 0.0;
    animPause := False;

    // UI required variables
    for i := 0 to animCount - 1 do
        animNames[i] := anims[i].name;

    dropdownEditMode0 := False;
    dropdownEditMode1 := False;
    animFrameProgress0 := 0.0;
    animFrameProgress1 := 0.0;
    animBlendProgress := 0.0;

    SetTargetFPS(60);

    // Main game loop
    while not WindowShouldClose() do
    begin
        // Update
        UpdateCamera(@camera, CAMERA_ORBITAL);

        if IsKeyPressed(KEY_P) then
            animPause := not animPause;

        if not animPause then
        begin
            // Start transition from anim0[] to anim1[]
            if IsKeyPressed(KEY_SPACE) and not animTransition then
            begin
                if currentAnimPlaying = 0 then
                begin
                    // Transition anim0 --> anim1
                    nextAnimToPlay := 1;
                    animCurrentFrame1 := 0.0;
                end
                else
                begin
                    // Transition anim1 --> anim0
                    nextAnimToPlay := 0;
                    animCurrentFrame0 := 0.0;
                end;

                // Set animation transition
                animTransition := True;
                animBlendTimeCounter := 0.0;
                animBlendFactor := 0.0;
            end;

            if animTransition then
            begin
                // Playing anim0 and anim1 at the same time
                animCurrentFrame0 := animCurrentFrame0 + animFrameSpeed0;
                if animCurrentFrame0 >= anims[animIndex0].keyframeCount then
                    animCurrentFrame0 := 0.0;

                animCurrentFrame1 := animCurrentFrame1 + animFrameSpeed1;
                if animCurrentFrame1 >= anims[animIndex1].keyframeCount then
                    animCurrentFrame1 := 0.0;

                // Increment blend factor over time
                animBlendFactor := animBlendTimeCounter / animBlendTime;
                animBlendTimeCounter := animBlendTimeCounter + GetFrameTime();
                animBlendProgress := animBlendFactor;

                // Update model with animations blending
                if nextAnimToPlay = 1 then
                begin
                    // Blend anim0 --> anim1
                    UpdateModelAnimationEx(model, anims[animIndex0], animCurrentFrame0,
                        anims[animIndex1], animCurrentFrame1, animBlendFactor);
                end
                else
                begin
                    // Blend anim1 --> anim0
                    UpdateModelAnimationEx(model, anims[animIndex1], animCurrentFrame1,
                        anims[animIndex0], animCurrentFrame0, animBlendFactor);
                end;

                // Check if transition completed
                if animBlendFactor > 1.0 then
                begin
                    // Reset frame states
                    if currentAnimPlaying = 0 then
                        animCurrentFrame0 := 0.0
                    else if currentAnimPlaying = 1 then
                        animCurrentFrame1 := 0.0;

                    currentAnimPlaying := nextAnimToPlay;
                    animBlendFactor := 0.0;
                    animTransition := False;
                    animBlendTimeCounter := 0.0;
                end;
            end
            else
            begin
                // Play only one anim, the current one
                if currentAnimPlaying = 0 then
                begin
                    // Playing anim0 at defined speed
                    animCurrentFrame0 := animCurrentFrame0 + animFrameSpeed0;
                    if animCurrentFrame0 >= anims[animIndex0].keyframeCount then
                        animCurrentFrame0 := 0.0;
                    UpdateModelAnimation(model, anims[animIndex0], Trunc(animCurrentFrame0));
                end
                else if currentAnimPlaying = 1 then
                begin
                    // Playing anim1 at defined speed
                    animCurrentFrame1 := animCurrentFrame1 + animFrameSpeed1;
                    if animCurrentFrame1 >= anims[animIndex1].keyframeCount then
                        animCurrentFrame1 := 0.0;
                    UpdateModelAnimation(model, anims[animIndex1], Trunc(animCurrentFrame1));
                end;
            end;
        end;

        // Update progress bars values with current frame for each animation
        animFrameProgress0 := animCurrentFrame0;
        animFrameProgress1 := animCurrentFrame1;

        // Draw
        BeginDrawing();
            ClearBackground(RAYWHITE);

            BeginMode3D(camera);
                DrawModel(model, position, 1.0, WHITE);
                DrawGrid(10, 1.0);
            EndMode3D();

            if animTransition then
                DrawText('ANIM TRANSITION BLENDING!', 170, 50, 30, BLUE);

            // Draw UI elements
            if dropdownEditMode0 then GuiDisable();
            GuiSlider(RectangleCreate(10, 38, 160, 12),
                nil, PChar(TextFormat('x%.1f', animFrameSpeed0)), @animFrameSpeed0, 0.1, 2.0);
            GuiEnable();

            if dropdownEditMode1 then GuiDisable();
            GuiSlider(RectangleCreate(GetScreenWidth() - 170, 38, 160, 12),
                PChar(TextFormat('%.1fx', animFrameSpeed1)), nil, @animFrameSpeed1, 0.1, 2.0);
            GuiEnable();

            // Draw animation selectors for blending transition
            GuiSetStyle(DROPDOWNBOX, DROPDOWN_ITEMS_SPACING, 1);

            if (GuiDropdownBox(RectangleCreate( 10, 10, 160, 24 ), TextJoin(animNames, animCount, ';'),
               @animIndex0, dropdownEditMode0)) = 1  then dropdownEditMode0 := not dropdownEditMode0;


            // Blending process progress bar
            if nextAnimToPlay = 1 then
                GuiSetStyle(PROGRESSBAR, PROGRESS_SIDE, 0) // Left-->Right
            else
                GuiSetStyle(PROGRESSBAR, PROGRESS_SIDE, 1); // Right-->Left

            GuiProgressBar(RectangleCreate(180, 14, 440, 16), nil, nil,
                @animBlendProgress, 0.0, 1.0);
            GuiSetStyle(PROGRESSBAR, PROGRESS_SIDE, 0); // Reset to Left-->Right


            if (GuiDropdownBox(RectangleCreate( GetScreenWidth() - 170, 10, 160, 24 ),
            TextJoin(animNames, animCount, ';'),
                @animIndex1, dropdownEditMode1)) = 1 then dropdownEditMode1 := not  dropdownEditMode1;



            // Draw playing timeline with keyframes for anim0[]
            GuiProgressBar(RectangleCreate(60, GetScreenHeight() - 60, GetScreenWidth() - 180, 20),
                'ANIM 0',
                PChar(TextFormat('FRAME: %.2f / %d', animFrameProgress0, anims[animIndex0].keyframeCount)),
                @animFrameProgress0, 0.0, anims[animIndex0].keyframeCount);

            for i := 0 to anims[animIndex0].keyframeCount - 1 do
                DrawRectangle(
                    60 + Round(((GetScreenWidth() - 180) / anims[animIndex0].keyframeCount) * i),
                    GetScreenHeight() - 60, 1, 20, BLUE);

            // Draw playing timeline with keyframes for anim1[]
            GuiProgressBar(RectangleCreate(60, GetScreenHeight() - 30, GetScreenWidth() - 180, 20),
                'ANIM 1',
                PChar(TextFormat('FRAME: %.2f / %d', animFrameProgress1, anims[animIndex1].keyframeCount)),
                @animFrameProgress1, 0.0, anims[animIndex1].keyframeCount);

            for i := 0 to anims[animIndex1].keyframeCount - 1 do
                DrawRectangle(
                    60 + Round(((GetScreenWidth() - 180) / anims[animIndex1].keyframeCount) * i),
                    GetScreenHeight() - 30, 1, 20, BLUE);

        EndDrawing();
    end;

    // De-Initialization
    UnloadModelAnimations(anims, animCount);
    UnloadModel(model);
    UnloadShader(skinningShader);

    CloseWindow();
end.
