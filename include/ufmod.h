#ifndef UFMOD_H
#define UFMOD_H

#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

// uFMOD constants
#define XM_RESOURCE       0
#define XM_MEMORY         1
#define XM_FILE           2
#define XM_NOLOOP         8
#define XM_SUSPENDED      16
#define uFMOD_MIN_VOL     0
#define uFMOD_MAX_VOL     25
#define uFMOD_DEFAULT_VOL 25

// uFMOD function declarations
void* WINAPI uFMOD_PlaySong(void *lpXM, void *param, int fdwSong);
void  WINAPI uFMOD_Jump2Pattern(unsigned int pat);
void  WINAPI uFMOD_Pause(void);
void  WINAPI uFMOD_Resume(void);
unsigned int WINAPI uFMOD_GetRowOrder(void);
unsigned int WINAPI uFMOD_GetStats(void);
unsigned int WINAPI uFMOD_GetTime(void);
unsigned char* WINAPI uFMOD_GetTitle(void);
void  WINAPI uFMOD_SetVolume(unsigned int vol);

#ifdef __cplusplus
}
#endif

#endif // UFMOD_H
