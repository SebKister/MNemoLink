# Mnemo v2 DMP File Format (File Version 5): #

**[No File Header]**


**[Per Section Header]** _(13 Bytes)_

    Fileversion; ( 5 for firmware >2.6.0)
    
    68;
    
    89;
    
    101;
    
    Year;
    
    Month;
    
    Day ;
    
    Hour ;
    
    Minute ;
    
    NameChar1;
    
    NameChar2;
    
    NameChar3;
    
    Direction ; ( 0=IN,1=OUT)

**[Per Shot]** _(36 Bytes)_

    57;
    
    67;
    
    77;
    
    Typeshot ; (0=CSA,1=CSB,2=STD,3=EOL)
    
    HeadingIN LSB;
    
    HeadingIN MSB;
    
    HeadingOUT LSB;
    
    HeadingOUT MSB;
    
    Length LSB;
    
    Length MSB;
    
    DepthIN LSB;
    
    DepthIN MSB;
    
    DepthOUT LSB;
    
    DepthOUT MSB;
    
    PitchIN LSB;
    
    PitchIN MSB;
    
    PitchOUT LSB;
    
    PitchOUT MSB;
    
    Left LSB;
    
    Left MSB;
    
    Right LSB;
    
    Right MSB;
    
    Up LSB;
    
    Up MSB;
    
    Down LSB;
    
    Down MSB;
    
    Temperature LSB;
    
    Temperature MSB;
    
    Hour;
    
    Minute;
    
    Second;
    
    MarkerIdx;
    
    95;
    
    25;
    
    35;

**[Section Termination]** _(36 Bytes)_

    57;67;77;3; [29 times 0;]95;25;35;