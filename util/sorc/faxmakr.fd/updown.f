      SUBROUTINE UPDOWN(FLDIN1,FLDIN2,IMAXI,JMAXI)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    UPDOWN      TO UPSIDE DOWN THE GRID DATA
C   PRGMMR: KRISHNA KUMAR      ORG: W/NP12    DATE: 1999-08-01
C
C ABSTRACT: TO UPSIDE DOWN THE GRID DATA
C
C PROGRAM HISTORY LOG:
C   89-06-28  ORIGINAL AUTHOR LUKE LIN
C   95-01-03  LUKE LIN   CONVERT IT CFT-77
C 1999-08-01  KRISHNA KUMAR CONVERTED THIS CODE FROM CRAY TO IBM RS/6000.
C
C USAGE:    CALL UPDOWN(FLDIN1,FLDIN2,IMAXI,JMAXI)
C   INPUT ARGUMENT LIST:
C     FLDIN1   - FLDIN1(IMAXI,JMAXI) INPUT GRID DATA
C     I/JMAXI  - DIMENSIONS OF SUBGRIDS
C
C   OUTPUT ARGUMENT LIST:
C     FLDIN2   - OUTPUT ARRAY FLDIN2(IMAXI,JMAXI)
C
C ATTRIBUTES:
C   LANGUAGE: F90
C   MACHINE:  IBM
C
C$$$
      REAL      FLDIN1(IMAXI,JMAXI)
      REAL      FLDIN2(IMAXI,JMAXI)
C
C-------------------------------------------------------------
C
C     ... UP-SIDE DOWN THE MAP FOR VARIAN
      DO 376 J=1,JMAXI
         DO 376 I=1,IMAXI
            FLDIN2(I,J)=FLDIN1(I,JMAXI-J+1)
  376 CONTINUE
      RETURN
      END