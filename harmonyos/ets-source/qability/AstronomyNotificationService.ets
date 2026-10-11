import { notificationManager } from '@kit.NotificationKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import hilog from '@ohos.hilog'

export interface AstronomyNotificationPayload {
  id: number
  title: string
  text: string
  additionalText?: string
  lines?: string[]
}

export class AstronomyNotificationService {
  private static readonly DOMAIN = 0x0000
  private static readonly TAG = 'StellariumNotification'

  public static async isEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled()
    } catch (error) {
      const failure = error as BusinessError
      hilog.error(AstronomyNotificationService.DOMAIN, AstronomyNotificationService.TAG, 'notification status failed: %{public}s', failure.message)
      return false
    }
  }

  public static async requestAuthorization(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification(context)
      return await AstronomyNotificationService.isEnabled()
    } catch (error) {
      const failure = error as BusinessError
      hilog.warn(AstronomyNotificationService.DOMAIN, AstronomyNotificationService.TAG, 'notification authorization not granted: %{public}d', failure.code)
      return false
    }
  }

  public static async publish(payload: AstronomyNotificationPayload): Promise<boolean> {
    if (!await AstronomyNotificationService.isEnabled()) return false
    const request: notificationManager.NotificationRequest = payload.lines !== undefined
      ? {
          id: payload.id,
          content: {
            notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_MULTILINE,
            multiLine: {
              title: payload.title,
              text: payload.text,
              briefText: payload.additionalText ?? payload.text,
              longTitle: payload.title,
              lines: payload.lines
            }
          }
        } : {
          id: payload.id,
          content: {
            notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
            normal: {
              title: payload.title,
              text: payload.text,
              additionalText: payload.additionalText ?? ''
            }
          }
        }
    return new Promise<boolean>((resolve) => {
      notificationManager.publish(request, (error?: BusinessError) => {
        if (error !== undefined) {
          hilog.error(AstronomyNotificationService.DOMAIN, AstronomyNotificationService.TAG, 'notification publish failed: %{public}d', error.code)
          resolve(false)
          return
        }
        resolve(true)
      })
    })
  }

  public static cancel(id: number): void {
    notificationManager.cancel(id)
  }
}
