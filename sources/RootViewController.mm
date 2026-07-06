#import "RootViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include "ENCRYPT/xorstr.hpp"
#import "DODoubleHelixIndicator.h"

// กำหนดสีสไตล์ GitHub Dark Mode
#define BG_COLOR [UIColor colorWithRed:13.0/255.0 green:17.0/255.0 blue:23.0/255.0 alpha:1.0]
#define CARD_COLOR [UIColor colorWithRed:22.0/255.0 green:27.0/255.0 blue:34.0/255.0 alpha:0.8]
#define BORDER_COLOR [UIColor colorWithRed:48.0/255.0 green:54.0/255.0 blue:61.0/255.0 alpha:0.8]
#define TEXT_COLOR [UIColor colorWithRed:201.0/255.0 green:209.0/255.0 blue:217.0/255.0 alpha:1.0]
#define ACCENT_GREEN [UIColor colorWithRed:35.0/255.0 green:134.0/255.0 blue:54.0/255.0 alpha:1.0]

@interface RootViewController () <UIDocumentPickerDelegate, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource> {
    UITextField *usernameField;
    UITextField *tokenField;
    UITextField *repoField;
    UITextField *branchField;
    UIButton *uploadButton;
    UILabel *fileInfoLabel;
    
    NSURL *selectedFileUrl;
    NSString *workflowYamlContent;
    UIImageView *repoArrowImageView; // ตัวแปรสำหรับเก็บป้ายลูกศรหมุนของช่อง Repo
    
    UIPickerView *repoPickerView;    // ตัวเลือกหมุนสำหรับรายชื่อ Repo
    NSMutableArray *repoListArray;   // อาร์เรย์เก็บรายชื่อ Repo ที่ดึงมาจาก GitHub API
}
@property (nonatomic, strong) DODoubleHelixIndicator *loadingIndicator;
@end

@implementation RootViewController

- (BOOL)shouldAutorotate { return NO; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = BG_COLOR;
    
    [self setupWorkflowString];
    [self setupNativeUI];
    [self setupLoadingIndicator];
    [self loadSavedData];
    
    // ลงทะเบียนสิทธิ์การตรวจจับการเคาะหน้าจอเพื่อสลับเก็บแป้นพิมพ์ภายนอก
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboardFromView)];
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
}

- (void)dismissKeyboardFromView {
    [self.view endEditing:YES];
}

- (void)setupWorkflowString {
    // โค้ด YAML (v2) สำหรับแตกไฟล์อัตโนมัติเมื่อเจอนามสกุล .zip บน GitHub Actions
    workflowYamlContent = @"name: Auto Unzip Any Archive\n\n"
    "on:\n"
    "  push:\n"
    "    paths:\n"
    "      - '**.zip'\n\n"
    "permissions:\n"
    "  contents: write\n\n"
    "jobs:\n"
    "  unzip-and-clean:\n"
    "    runs-on: ubuntu-latest\n"
    "    steps:\n"
    "      - name: Checkout Code\n"
    "        uses: actions/checkout@v4\n\n"
    "      - name: Extract all zip files to Root\n"
    "        run: |\n"
    "          for f in *.zip; do\n"
    "            [ -e \"$f\" ] || continue\n"
    "            echo \"กำลังจัดการแตกไฟล์: $f\"\n"
    "            FOLDER_NAME=\"${f%.zip}\"\n"
    "            unzip -o \"$f\" -d ./\n"
    "            rm \"$f\"\n"
    "            if [ -d \"$FOLDER_NAME\" ]; then\n"
    "               echo \"พบโฟลเดอร์ซ้อนชื่อ $FOLDER_NAME -> กำลังบังคับดึงไฟล์ภายในทั้งหมดออกมาที่หน้าแรก\"\n"
    "               mv \"$FOLDER_NAME\"/* ./ 2>/dev/null || true\n"
    "               mv \"$FOLDER_NAME\"/.* ./ 2>/dev/null || true\n"
    "               rm -rf \"$FOLDER_NAME\"\n"
    "            fi\n"
    "          done\n\n"
    "      - name: Commit and Push Changes back to Repo\n"
    "        run: |\n"
    "          git config --global user.name \"github-actions[bot]\"\n"
    "          git config --global user.email \"41898282+github-actions[bot]@users.noreply.github.com\"\n"
    "          git add .\n"
    "          if ! git diff-index --quiet HEAD; then\n"
    "            git commit -m \"Unpack and force flatten nested zip folder contents to root\"\n"
    "            git push\n"
    "          else\n"
    "            echo \"ไม่มีการเปลี่ยนแปลงโครงสร้างไฟล์เพิ่มเติม\"\n"
    "          fi\n";
}

- (void)setupNativeUI {
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scrollView];
    
    UIView *cardView = [[UIView alloc] initWithFrame:CGRectMake(20, 60, self.view.frame.size.width - 40, 520)];
    cardView.backgroundColor = CARD_COLOR;
    cardView.layer.borderColor = BORDER_COLOR.CGColor;
    cardView.layer.borderWidth = 1.0;
    cardView.layer.cornerRadius = 16.0;
    [scrollView addSubview:cardView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 20, cardView.frame.size.width - 20, 30)];
    titleLabel.text = @"GitHub Zip Native Uploader";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [cardView addSubview:titleLabel];
    
    // สร้างฟิลด์ข้อมูลต่าง ๆ
    usernameField = [self createTextFieldWithPlaceholder:@"GitHub Username (เช่น Octocat)" yPos:70 toView:cardView];
    tokenField = [self createTextFieldWithPlaceholder:@"GitHub Token (ghp_xxx)" yPos:130 toView:cardView];
    tokenField.secureTextEntry = YES;
    
    repoField = [self createTextFieldWithPlaceholder:@"Repository Name" yPos:190 toView:cardView];
    branchField = [self createTextFieldWithPlaceholder:@"Branch (default: main)" yPos:250 toView:cardView];
    
    // ตั้งค่าเพิ่มรูปไอคอนลูกศรแบบ chevron.down ด้านท้ายของช่องกรอกข้อมูล Repo
    UIView *rightContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 32, 40)];
    repoArrowImageView = [[UIImageView alloc] initWithFrame:CGRectMake(6, 14, 12, 12)];
    repoArrowImageView.tintColor = [UIColor grayColor];
    
    if (@available(iOS 13.0, *)) {
        repoArrowImageView.image = [[UIImage systemImageNamed:@"chevron.down"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        // Fallback วาดสัญลักษณ์ลูกศรชี้ลงล่างหากรันบนระบบเก่ากว่า iOS 13
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(12, 12), NO, 0.0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetStrokeColorWithColor(context, [UIColor grayColor].CGColor);
        CGContextSetLineWidth(context, 2.0);
        CGContextMoveToPoint(context, 1, 3);
        CGContextAddLineToPoint(context, 6, 9);
        CGContextAddLineToPoint(context, 11, 3);
        CGContextStrokePath(context);
        UIImage *arrowImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        repoArrowImageView.image = arrowImg;
    }
    
    [rightContainerView addSubview:repoArrowImageView];
    repoField.rightView = rightContainerView;
    repoField.rightViewMode = UITextFieldViewModeAlways;
    
    // เตรียมระบบ UIPickerView สำหรับแสดงและเลือกรายชื่อคลังข้อมูล
    repoListArray = [[NSMutableArray alloc] init];
    repoPickerView = [[UIPickerView alloc] init];
    repoPickerView.delegate = self;
    repoPickerView.dataSource = self;
    
    // สร้างแถบเครื่องมือปิด/เลือกด้านบน Picker
    UIToolbar *pickerToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 40)];
    pickerToolbar.barStyle = UIBarStyleBlack;
    pickerToolbar.translucent = YES;
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"เลือก" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboardFromView)];
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    [pickerToolbar setItems:@[flexibleSpace, doneButton]];
    
    repoField.inputView = repoPickerView;
    repoField.inputAccessoryView = pickerToolbar;
    
    // ผูก Action ให้คอยตรวจจับการเปลี่ยนแปลงของ Username/Token เพื่อดึง Repo อัตโนมัติ
    [usernameField addTarget:self action:@selector(fetchGitHubRepositoriesNative) forControlEvents:UIControlEventEditingChanged];
    [tokenField addTarget:self action:@selector(fetchGitHubRepositoriesNative) forControlEvents:UIControlEventEditingChanged];
    
    // ช่องแสดงข้อมูลไฟล์ย่อยที่เลือก
    fileInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 310, cardView.frame.size.width - 40, 70)];
    fileInfoLabel.backgroundColor = [UIColor colorWithRed:22.0/255.0 green:27.0/255.0 blue:34.0/255.0 alpha:1.0];
    fileInfoLabel.layer.borderColor = BORDER_COLOR.CGColor;
    fileInfoLabel.layer.borderWidth = 1.0;
    fileInfoLabel.layer.cornerRadius = 8.0;
    fileInfoLabel.numberOfLines = 0;
    fileInfoLabel.textColor = [UIColor lightGrayColor];
    fileInfoLabel.font = [UIFont systemFontOfSize:12];
    fileInfoLabel.text = @"ยังไม่ได้เลือกไฟล์\n รองรับระบบแตกไฟล์ย่อยมาหน้า Root อัตโนมัติ (v2)";
    [cardView addSubview:fileInfoLabel];
    
    // ปุ่มสั่งงานหลัก
    uploadButton = [UIButton buttonWithType:UIButtonTypeCustom];
    uploadButton.frame = CGRectMake(20, 410, cardView.frame.size.width - 40, 45);
    uploadButton.backgroundColor = ACCENT_GREEN;
    uploadButton.layer.cornerRadius = 8.0;
    [uploadButton setTitle:@"เลือกไฟล์ .zip เพื่อเริ่มอัปโหลด" forState:UIControlStateNormal];
    [uploadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    uploadButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [uploadButton addTarget:self action:@selector(selectFileBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:uploadButton];
}

- (UITextField *)createTextFieldWithPlaceholder:(NSString *)placeholder yPos:(CGFloat)y toView:(UIView *)parent {
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(20, y, parent.frame.size.width - 40, 40)];
    tf.backgroundColor = [UIColor colorWithRed:33.0/255.0 green:38.0/255.0 blue:45.0/255.0 alpha:1.0];
    tf.layer.borderColor = BORDER_COLOR.CGColor;
    tf.layer.borderWidth = 1.0;
    tf.layer.cornerRadius = 8.0;
    tf.textColor = [UIColor whiteColor];
    tf.font = [UIFont systemFontOfSize:14];
    tf.delegate = self;
    tf.returnKeyType = UIReturnKeyNext; // เปลี่ยนปุ่มรีเทิร์นบนแป้นพิมพ์ให้แสดงคำว่า ถัดไป (Next)
    
    // สร้าง Padding ด้านซ้ายของกล่องข้อความ
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 20)];
    tf.leftView = paddingView;
    tf.leftViewMode = UITextFieldViewModeAlways;
    
    tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: [UIColor grayColor]}];
    [parent addSubview:tf];
    return tf;
}

- (void)setupLoadingIndicator {
    self.loadingIndicator = [[DODoubleHelixIndicator alloc] init];
    self.loadingIndicator.center = self.view.center;
    self.loadingIndicator.hidden = YES;
    [self.view addSubview:self.loadingIndicator];
}

#pragma mark - GitHub Repository Fetcher (ระบบดึงรายชื่อ Repo อัตโนมัติ)
- (void)fetchGitHubRepositoriesNative {
    NSString *user = usernameField.text;
    NSString *token = tokenField.text;
    if (user.length == 0 || token.length == 0) return;
    
    NSString *urlStr = @"https://api.github.com/user/repos?per_page=100&sort=updated";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [request setValue:[NSString stringWithFormat:@"token %@", token] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/vnd.github.v3+json" forHTTPHeaderField:@"Accept"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            NSArray *repos = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([repos isKindOfClass:[NSArray class]]) {
                [self->repoListArray removeAllObjects];
                [self->repoListArray addObject:@"< สร้าง Repository ใหม่ >"];
                for (NSDictionary *repoDict in repos) {
                    NSString *name = repoDict[@"name"];
                    if (name) [self->repoListArray addObject:name];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->repoPickerView reloadAllComponents];
                });
            }
        }
    }] resume];
}

#pragma mark - UIPickerView DataSource & Delegate
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView { return 1; }
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component { return repoListArray.count; }
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component { return repoListArray[row]; }
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (row < repoListArray.count) {
        NSString *selected = repoListArray[row];
        if ([selected isEqualToString:@"< สร้าง Repository ใหม่ >"]) {
            repoField.inputView = nil; // อนุญาตให้แป้นพิมพ์ปกติขึ้นเพื่อพิมพ์สร้างชื่อใหม่
            repoField.text = @"";
            [repoField reloadInputViews];
        } else {
            repoField.text = selected;
        }
    }
}

#pragma mark - UITextFieldDelegate (การสลับฟิลด์ด้วยรีเทิร์นและการหมุนของ Arrow)

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField == repoField) {
        if (repoListArray.count <= 1) { [self fetchGitHubRepositoriesNative]; }
        [UIView animateWithDuration:0.25 animations:^{
            self->repoArrowImageView.transform = CGAffineTransformMakeRotation(M_PI); // หมุนลูกศรกลับหัวชี้ขึ้นบน 180 องศา (M_PI) เมื่อโฟกัสเปิดตัวเลือก
        }];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == repoField) {
        [UIView animateWithDuration:0.25 animations:^{
            self->repoArrowImageView.transform = CGAffineTransformIdentity; // หมุนกลับคืนลงข้างล่างตามเดิมเมื่อยกเลิกการโฟกัส
        }];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == usernameField) {
        [tokenField becomeFirstResponder];
    } else if (textField == tokenField) {
        [repoField becomeFirstResponder];
    } else if (textField == repoField) {
        [branchField becomeFirstResponder];
    } else if (textField == branchField) {
        [textField resignFirstResponder]; // ช่องสุดท้ายให้สั่งซ่อนปิดหน้าต่างคีย์บอร์ดลงมาทันที
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

#pragma mark - Data Persistence
- (void)saveUserData {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:usernameField.text forKey:@"native_gh_user"];
    [defaults setObject:tokenField.text forKey:@"native_gh_token"];
    [defaults setObject:repoField.text forKey:@"native_gh_repo"];
    [defaults setObject:branchField.text forKey:@"native_gh_branch"];
    [defaults synchronize];
}

- (void)loadSavedData {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    usernameField.text = [defaults objectForKey:@"native_gh_user"] ?: @"";
    tokenField.text = [defaults objectForKey:@"native_gh_token"] ?: @"";
    repoField.text = [defaults objectForKey:@"native_gh_repo"] ?: @"";
    branchField.text = [defaults objectForKey:@"native_gh_branch"] ?: @"main";
    if (usernameField.text.length > 0 && tokenField.text.length > 0) { [self fetchGitHubRepositoriesNative]; }
}

#pragma mark - Actions
- (void)selectFileBtnPressed {
    [self.view endEditing:YES];
    if (usernameField.text.length == 0 || tokenField.text.length == 0 || repoField.text.length == 0) {
        [self showAlert:@"ข้อผิดพลาด" message:@"กรุณากรอกข้อมูล GitHub ให้ครบถ้วนก่อนเลือกไฟล์ครับ"];
        return;
    }
    [self saveUserData];
    
    UIDocumentPickerViewController *picker;
    if (@available(iOS 14.0, *)) {
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType typeWithFilenameExtension:@"zip"]] asCopy:YES];
    } else {
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.zip-archive"] inMode:UIDocumentPickerModeImport];
    }
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    selectedFileUrl = urls.firstObject;
    if (selectedFileUrl) {
        // ดึงขนาดไฟล์มาแสดงผลบนหน้าจอ
        NSError *error;
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:selectedFileUrl.path error:&error];
        NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
        long long fileSize = [fileSizeNumber longLongValue];
        double fileSizeInMB = (double)fileSize / (1024 * 1024);
        
        fileInfoLabel.text = [NSString stringWithFormat:@"ชื่อไฟล์ที่จะอัปโหลด: %@\nขนาดไฟล์: %.2f MB\nระบบกำลังรันผ่าน API Native", selectedFileUrl.lastPathComponent, fileSizeInMB];
        
        // เมื่อเลือกเสร็จให้สั่งเริ่มขบวนการสเต็ปการอัปโหลดไป GitHub ทันที
        [self startGitHubUploadProcess];
    }
}

#pragma mark - GitHub API Core Logic (Native Dynamic Upload Engine)
- (void)startGitHubUploadProcess {
    self.loadingIndicator.hidden = NO;
    [uploadButton setEnabled:NO];
    [uploadButton setTitle:@"กำลังตรวจสอบ Repository..." forState:UIControlStateNormal];
    
    NSString *user = usernameField.text;
    NSString *token = tokenField.text;
    NSString *repo = repoField.text;
    NSString *branch = branchField.text.length > 0 ? branchField.text : @"main";
    
    NSString *repoCheckUrl = [NSString stringWithFormat:@"https://api.github.com/repos/%@/%@", user, repo];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:repoCheckUrl]];
    [request setValue:[NSString stringWithFormat:@"token %@", token] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/vnd.github.v3+json" forHTTPHeaderField:@"Accept"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        if (httpResponse.statusCode == 404) {
            // ไม่พบ Repo -> ทำการสั่งสร้างใหม่ Native-way
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->uploadButton setTitle:@"กำลังสร้าง Repository ใหม่..." forState:UIControlStateNormal];
            });
            [self createNewRepoWithName:repo token:token branch:branch];
        } else if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
            // เจอ Repo อยู่แล้ว -> ไปทำขั้นตอนจัดการ Workflow ต่อเลย
            [self checkAndUploadWorkflowWithUser:user token:token repo:repo branch:branch];
        } else {
            [self handleUploadFailure:@"ไม่สามารถยืนยันสิทธิ์หรือติดต่อ GitHub API ได้"];
        }
    }] resume];
}

- (void)createNewRepoWithName:(NSString *)repo token:(NSString *)token branch:(NSString *)branch {
    NSString *createUrl = @"https://api.github.com/user/repos";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:createUrl]];
    [request setHTTPMethod:@"POST"];
    [request setValue:[NSString stringWithFormat:@"token %@", token] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *body = @{@"name": repo, @"private": @NO, @"auto_init": @YES};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode == 201) {
            [NSThread sleepForTimeInterval:3.0]; // หน่วงรอระบบเซิร์ฟเวอร์เคลียร์ git นิดนึง
            [self checkAndUploadWorkflowWithUser:self->usernameField.text token:token repo:repo branch:branch];
        } else {
            [self handleUploadFailure:@"การขอบังคับสร้าง Repository ใหม่ล้มเหลว"];
        }
    }] resume];
}

- (void)checkAndUploadWorkflowWithUser:(NSString *)user token:(NSString *)token repo:(NSString *)repo branch:(NSString *)branch {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->uploadButton setTitle:@"กำลังติดตั้งระบบแตกไฟล์ย่อย (yml)..." forState:UIControlStateNormal];
    });
    
    NSString *wfPath = @".github/workflows/unzip.yml";
    NSString *wfUrl = [NSString stringWithFormat:@"https://api.github.com/repos/%@/%@/contents/%@", user, repo, wfPath];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:wfUrl]];
    [request setValue:[NSString stringWithFormat:@"token %@", token] forHTTPHeaderField:@"Authorization"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *currentWfSha = nil;
        
        if (httpResponse.statusCode == 200 && data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            currentWfSha = json[@"sha"];
        }
        
        // แปลงไฟล์ YAML เป็น Base64 ส่งขึ้น API
        NSData *wfData = [self->workflowYamlContent dataUsingEncoding:NSUTF8StringEncoding];
        NSString *wfBase64 = [wfData base64EncodedStringWithOptions:0];
        
        NSMutableURLRequest *putRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:wfUrl]];
        [putRequest setHTTPMethod:@"PUT"];
        [putRequest setValue:[NSString stringWithFormat:@"token %@", token] forHTTPHeaderField:@"Authorization"];
        [putRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
            @"message": @"Update native smart flatten unzip workflow v2",
            @"content": wfBase64,
            @"branch": branch
        }];
        if (currentWfSha) body[@"sha"] = currentWfSha;
        
        putRequest.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:putRequest completionHandler:^(NSData *dData, NSURLResponse *pResponse, NSError *pError) {
            // อัปเดตไฟล์ Workflow เสร็จสิ้น -> ลุยส่งก้อนไฟล์ .zip ต่อไปทันที
            [self uploadActualZipFileWithUser:user token:token repo:repo branch:branch];
        }] resume];
    }] resume];
}

- (void)uploadActualZipFileWithUser:(NSString *)user token:(NSString *)token repo:(NSString *)repo branch:(NSString *)branch {
    NSString *fileName = selectedFileUrl.lastPathComponent;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->uploadButton setTitle:[NSString stringWithFormat:@"กำลังส่งไฟล์ %@...", fileName] forState:UIControlStateNormal];
    });
    
    NSString *fileUrlString = [NSString stringWithFormat:@"https://api.github.com/repos/%@/%@/contents/%@", user, repo, [fileName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]];
    
    // ตรวจหาค่า SHA ของไฟล์ Zip ตัวเดิม (ถ้ามี) เพื่อทำการเขียนข้อมูลทับ
    NSMutableURLRequest *checkRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:fileUrlString]];
    [checkRequest setValue:[NSString stringWithFormat:@"token %@", token] forHTTPHeaderField:@"Authorization"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:checkRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *zipSha = nil;
        if (httpResponse.statusCode == 200 && data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            zipSha = json[@"sha"];
        }
        
        // โหลดข้อมูลดิบของไฟล์ Zip และถอดรหัสเป็นสตรีม Base64
        NSData *zipData = [NSData dataWithContentsOfURL:self->selectedFileUrl];
        NSString *zipBase64 = [zipData base64EncodedStringWithOptions:0];
        
        NSMutableURLRequest *uploadRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:fileUrlString]];
        [uploadRequest setHTTPMethod:@"PUT"];
        [uploadRequest setValue:[NSString stringWithFormat:@"token %@", token] forHTTPHeaderField:@"Authorization"];
        [uploadRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
            @"message": [NSString stringWithFormat:@"Upload %@ via Custom Objective-C Mobile App", fileName],
            @"content": zipBase64,
            @"branch": branch
        }];
        if (zipSha) body[@"sha"] = zipSha;
        
        uploadRequest.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:uploadRequest completionHandler:^(NSData *uData, NSURLResponse *uResponse, NSError *uError) {
            NSHTTPURLResponse *finalResponse = (NSHTTPURLResponse *)uResponse;
            if (finalResponse.statusCode == 200 || finalResponse.statusCode == 201) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.loadingIndicator.hidden = YES;
                    [self->uploadButton setEnabled:YES];
                    [self->uploadButton setTitle:@"อัปโหลดสำเร็จ" forState:UIControlStateNormal];
                    [self showAlert:@"เรียบร้อย!" message:@"ส่งไฟล์ขึ้นเรียบร้อย ระบบดึงโครงสร้างย่อยไปหน้า Root เริ่มทำงานแล้ว"];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self->uploadButton setTitle:@"เลือกไฟล์ .zip เพื่อเริ่มอัปโหลด" forState:UIControlStateNormal];
                    });
                });
            } else {
                [self handleUploadFailure:@"เซิร์ฟเวอร์ปฏิเสธการส่งบล็อกข้อมูลไฟล์ขนาดใหญ่"];
            }
        }] resume];
    }] resume];
}

- (void)handleUploadFailure:(NSString *)reason {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.loadingIndicator.hidden = YES;
        [self->uploadButton setEnabled:YES];
        [self->uploadButton setTitle:@"เกิดข้อผิดพลาด ลองใหม่อีกครั้ง" forState:UIControlStateNormal];
        [self showAlert:@"อัปโหลดไม่สำเร็จ" message:reason];
    });
}

#pragma mark - Helper UI Elements
- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"ตกลง" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
