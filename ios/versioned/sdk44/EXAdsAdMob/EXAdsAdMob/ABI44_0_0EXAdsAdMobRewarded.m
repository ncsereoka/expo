#import <ABI44_0_0ExpoModulesCore/ABI44_0_0EXUIManager.h>
#import <ABI44_0_0ExpoModulesCore/ABI44_0_0EXEventEmitterService.h>
#import <ABI44_0_0EXAdsAdMob/ABI44_0_0EXAdsAdMobRewarded.h>
#import <ABI44_0_0ExpoModulesCore/ABI44_0_0EXUtilitiesInterface.h>

static NSString *const ABI44_0_0EXAdsAdMobRewardedUserDidEarnReward = @"rewardedVideoUserDidEarnReward";
static NSString *const ABI44_0_0EXAdsAdMobRewardedDidLoad = @"rewardedVideoDidLoad";
static NSString *const ABI44_0_0EXAdsAdMobRewardedDidFailToLoad = @"rewardedVideoDidFailToLoad";
static NSString *const ABI44_0_0EXAdsAdMobRewardedDidPresent = @"rewardedVideoDidPresent";
static NSString *const ABI44_0_0EXAdsAdMobRewardedDidFailToPresent = @"rewardedVideoDidFailToPresent";
static NSString *const ABI44_0_0EXAdsAdMobRewardedDidDismiss = @"rewardedVideoDidDismiss";

@interface ABI44_0_0EXAdsAdMobRewarded ()

@property (nonatomic, weak) id<ABI44_0_0EXEventEmitterService> eventEmitter;
@property (nonatomic, weak) id<ABI44_0_0EXUtilitiesInterface> utilities;
@property (nonatomic, strong) GADRewardedAd *rewardedAd;

@end

@implementation ABI44_0_0EXAdsAdMobRewarded {
  NSString *_adUnitID;
  BOOL _hasListeners;
  ABI44_0_0EXPromiseResolveBlock _requestAdResolver;
  ABI44_0_0EXPromiseRejectBlock _requestAdRejecter;
  ABI44_0_0EXPromiseResolveBlock _showAdResolver;
}

ABI44_0_0EX_EXPORT_MODULE(ExpoAdsAdMobRewardedVideoAdManager);

- (void)setModuleRegistry:(ABI44_0_0EXModuleRegistry *)moduleRegistry
{
  _utilities = [moduleRegistry getModuleImplementingProtocol:@protocol(ABI44_0_0EXUtilitiesInterface)];
  _eventEmitter = [moduleRegistry getModuleImplementingProtocol:@protocol(ABI44_0_0EXEventEmitterService)];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[
    ABI44_0_0EXAdsAdMobRewardedUserDidEarnReward,
    ABI44_0_0EXAdsAdMobRewardedDidLoad,
    ABI44_0_0EXAdsAdMobRewardedDidFailToLoad,
    ABI44_0_0EXAdsAdMobRewardedDidPresent,
    ABI44_0_0EXAdsAdMobRewardedDidFailToPresent,
    ABI44_0_0EXAdsAdMobRewardedDidDismiss,
  ];
}

- (void)startObserving {
  _hasListeners = YES;
}

- (void)_maybeSendEventWithName:(NSString *)name body:(id)body {
  if (_hasListeners) {
    [_eventEmitter sendEventWithName:name body:body];
  }
}

- (void)stopObserving {
  _hasListeners = NO;
}

ABI44_0_0EX_EXPORT_METHOD_AS(setAdUnitID,
                    setAdUnitID:(NSString *)adUnitID
                    resolver:(ABI44_0_0EXPromiseResolveBlock)resolve
                    rejecter:(ABI44_0_0EXPromiseRejectBlock)reject)
{
  _adUnitID = adUnitID;
  resolve(nil);
}

ABI44_0_0EX_EXPORT_METHOD_AS(requestAd,
                    requestAdWithAdditionalRequestParams:(NSDictionary *)additionalRequestParams
                    resolver:(ABI44_0_0EXPromiseResolveBlock)resolve
                    rejecter:(ABI44_0_0EXPromiseRejectBlock)reject)
{
  if (_requestAdRejecter == nil) {
    _requestAdResolver = resolve;
    _requestAdRejecter = reject;
    
    self.rewardedAd = [[GADRewardedAd alloc] initWithAdUnitID:_adUnitID];
    GADRequest *request = [GADRequest request];
    if (additionalRequestParams) {
      GADExtras *extras = [[GADExtras alloc] init];
      extras.additionalParameters = additionalRequestParams;
      [request registerAdNetworkExtras:extras];
    }
    ABI44_0_0EX_WEAKIFY(self);
    dispatch_async(dispatch_get_main_queue(), ^{
      ABI44_0_0EX_ENSURE_STRONGIFY(self);
      [self.rewardedAd loadRequest:request
                 completionHandler:^(GADRequestError * _Nullable error) {
        ABI44_0_0EX_ENSURE_STRONGIFY(self);
        if (error) {
          [self _maybeSendEventWithName:ABI44_0_0EXAdsAdMobRewardedDidFailToLoad
                                   body:@{ @"name": [error description] }];
          self->_requestAdRejecter(@"E_AD_REQUEST_FAILED", [error description], error);
          [self _cleanupRequestAdPromise];
        } else {
          [self _maybeSendEventWithName:ABI44_0_0EXAdsAdMobRewardedDidLoad body:nil];
          self->_requestAdResolver(nil);
          [self _cleanupRequestAdPromise];
        }
      }];
    });
  } else {
    reject(@"E_AD_REQUESTING", @"An ad is already being requested, await the previous promise.", nil);
  }
}

ABI44_0_0EX_EXPORT_METHOD_AS(showAd,
                    showAd:(ABI44_0_0EXPromiseResolveBlock)resolve
                    rejecter:(ABI44_0_0EXPromiseRejectBlock)reject)
{
  if (_showAdResolver == nil && self.rewardedAd.isReady) {
    _showAdResolver = resolve;
    ABI44_0_0EX_WEAKIFY(self);
    dispatch_async(dispatch_get_main_queue(), ^{
      ABI44_0_0EX_ENSURE_STRONGIFY(self);
      [self.rewardedAd presentFromRootViewController:self.utilities.currentViewController delegate:self];
    });
  } else if (self.rewardedAd.isReady) {
    reject(@"E_AD_BEING_SHOWN", @"Ad is already being shown, await the previous promise.", nil);
  } else {
    reject(@"E_AD_NOT_READY", @"Ad is not ready.", nil);
  }
}

ABI44_0_0EX_EXPORT_METHOD_AS(dismissAd,
                    dismissAd:(ABI44_0_0EXPromiseResolveBlock)resolve
                    rejecter:(ABI44_0_0EXPromiseRejectBlock)reject)
{
  ABI44_0_0EX_WEAKIFY(self);
  dispatch_async(dispatch_get_main_queue(), ^{
    ABI44_0_0EX_ENSURE_STRONGIFY(self);
    UIViewController *presentedViewController = self.utilities.currentViewController;
    if (presentedViewController != nil && [NSStringFromClass([presentedViewController class]) isEqualToString:@"GADInterstitialViewController"]) {
      [presentedViewController dismissViewControllerAnimated:true completion:^{
        resolve(nil);
      }];
    } else {
      reject(@"E_AD_NOT_SHOWN", @"Ad is not being shown.", nil);
    }
  });
}

ABI44_0_0EX_EXPORT_METHOD_AS(getIsReady,
                    getIsReady:(ABI44_0_0EXPromiseResolveBlock)resolve
                    rejecter:(ABI44_0_0EXPromiseRejectBlock)reject)
{
  resolve([NSNumber numberWithBool:self.rewardedAd.isReady]);
}


- (void)_cleanupRequestAdPromise
{
  _requestAdResolver = nil;
  _requestAdRejecter = nil;
}

- (void)rewardedAd:(GADRewardedAd *)rewardedAd userDidEarnReward:(GADAdReward *)reward {
  [self _maybeSendEventWithName:ABI44_0_0EXAdsAdMobRewardedUserDidEarnReward
                           body:@{ @"type": reward.type, @"amount": reward.amount }];
}

- (void)rewardedAdDidPresent:(GADRewardedAd *)rewardedAd {
  [self _maybeSendEventWithName:ABI44_0_0EXAdsAdMobRewardedDidPresent body:nil];
  _showAdResolver(nil);
  _showAdResolver = nil;
}

- (void)rewardedAd:(GADRewardedAd *)rewardedAd didFailToPresentWithError:(NSError *)error
{
  [self _maybeSendEventWithName:ABI44_0_0EXAdsAdMobRewardedDidFailToPresent
                           body:@{ @"name": [error description] }];
  _requestAdRejecter(@"E_AD_REQUEST_FAILED", [error description], error);
  [self _cleanupRequestAdPromise];
}

- (void)rewardedAdDidDismiss:(GADRewardedAd *)rewardedAd {
  [self _maybeSendEventWithName:ABI44_0_0EXAdsAdMobRewardedDidDismiss body:nil];
}

@end

