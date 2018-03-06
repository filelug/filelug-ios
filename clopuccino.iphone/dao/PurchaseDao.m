#import "PurchaseDao.h"
#import "ClopuccinoCoreData.h"
#import "PurchaseWithoutManaged.h"
#import "Purchase+CoreDataClass.h"
#import "UserDao.h"
#import "User+CoreDataClass.h"

@interface PurchaseDao()

@property(nonatomic, strong) ClopuccinoCoreData *coreData;

@property(nonatomic, strong) UserDao *userDao;

@end

@implementation PurchaseDao {

}

- (id)init {
    self = [super init];
    if (self) {
        _coreData = [ClopuccinoCoreData defaultCoreData];

        _userDao = [[UserDao alloc] init];
    }

    return self;
}

// make sure it is wrapped under performBlock: or performBlockAndWait:
- (PurchaseWithoutManaged *)purchaseWithoutManagedFromPurchase:(Purchase *)purchase {
    PurchaseWithoutManaged *purchaseWithoutManaged;

    if (purchase) {
        purchaseWithoutManaged = [[PurchaseWithoutManaged alloc] initWithPurchaseId:purchase.purchaseId productId:purchase.productId userId:purchase.user.userId quantity:purchase.quantity vendorTransactionId:purchase.vendorTransactionId vendorUserId:purchase.vendorUserId purchaseTimestamp:purchase.purchaseTimestamp pending:purchase.pending];
    }

    return purchaseWithoutManaged;
}

- (void)createPurchaseFromPurchaseWithoutMaanaged:(PurchaseWithoutManaged *)purchaseWithoutManaged {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        User *user = [self.userDao findUserById:purchaseWithoutManaged.userId managedObjectContext:moc];

        if (user) {
            Purchase *purchase = [NSEntityDescription insertNewObjectForEntityForName:@"Purchase" inManagedObjectContext:moc];

            purchase.purchaseId = purchaseWithoutManaged.purchaseId;
            purchase.productId = purchaseWithoutManaged.productId;
            purchase.quantity = purchaseWithoutManaged.quantity;
            purchase.vendorTransactionId = purchaseWithoutManaged.vendorTransactionId;
            purchase.vendorUserId = purchaseWithoutManaged.vendorUserId;
            purchase.purchaseTimestamp = purchaseWithoutManaged.purchaseTimestamp;
            purchase.pending = purchaseWithoutManaged.pending;
            purchase.user = user;

            [self.coreData saveContext:moc];
        }
    }];
}

- (NSArray *)findPendingPurchasesForUserId:(NSString *)userId error:(NSError * __autoreleasing *)error {
    __block NSMutableArray *pendingPurchases = [NSMutableArray array];
    __block NSError *findError;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        User *user = [self.userDao findUserById:userId managedObjectContext:moc];

        if (user) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Purchase"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"user == %@ AND pending == %@", user, @YES];
            [request setPredicate:predicate];

            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"purchaseTimestamp" ascending:YES];
            [request setSortDescriptors:@[sortDescriptor]];

            NSArray *purchases = [moc executeFetchRequest:request error:&findError];

            if (purchases && [purchases count] > 0) {
                for (Purchase *purchase in purchases) {
                    [pendingPurchases addObject:[self purchaseWithoutManagedFromPurchase:purchase]];
                }
            }
        }
    }];

    if (error && findError) {
        *error = findError;
    }

    return pendingPurchases;
}

- (void)updatePurchase:(PurchaseWithoutManaged *)purchaseWithoutManaged {
    if (purchaseWithoutManaged
            && purchaseWithoutManaged.purchaseId
            && purchaseWithoutManaged.productId
            && purchaseWithoutManaged.userId
            && purchaseWithoutManaged.quantity
            && purchaseWithoutManaged.vendorTransactionId
            && purchaseWithoutManaged.vendorUserId
            && purchaseWithoutManaged.purchaseTimestamp
            && purchaseWithoutManaged.pending) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            User *user = [self.userDao findUserById:purchaseWithoutManaged.userId managedObjectContext:moc];

            if (user) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Purchase"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"purchaseId == %@", user, purchaseWithoutManaged.purchaseId];
                [request setPredicate:predicate];

                NSError *fetchError;
                NSArray *fileTransfers = [moc executeFetchRequest:request error:&fetchError];

                if (fetchError) {
                    NSLog(@"Error on finding Purchase by purchase id: %@\n%@", purchaseWithoutManaged.purchaseId, fetchError);
                } else if (fileTransfers && [fileTransfers count] > 0) {
                    Purchase *purchase = fileTransfers[0];

                    purchase.productId = purchaseWithoutManaged.productId;
                    purchase.user = user;
                    purchase.quantity = purchaseWithoutManaged.quantity;
                    purchase.vendorTransactionId = purchaseWithoutManaged.vendorTransactionId;
                    purchase.vendorUserId = purchaseWithoutManaged.vendorUserId;
                    purchase.purchaseTimestamp = purchaseWithoutManaged.purchaseTimestamp;
                    purchase.pending = purchaseWithoutManaged.pending;

                    [self.coreData saveContext:moc];
                }
            }
        }];
    }
}


@end
