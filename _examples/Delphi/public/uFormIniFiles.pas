unit uFormIniFiles;

interface

uses
  Forms, Classes, IniFiles;

type
  TControlSaveFlag = (csfSaveAll, csfIgnoreTagOne, csfSaveOnlyTagOne, csfSaveTagZero);
  TFormStateOptions = set of (fsoWindowState, fsoPosition, fsoSize, fsoCaptionR, fsoCaptionW);

  TFormFileHelper = class
  public
    class function GetAppPath: string;
    class function ReadFromFile(const fname: string): string;
    class procedure SaveToFile(const fname, ctx: string);
    class procedure StrsFromFile(strs: TStrings; const fname: string);
    class procedure StrsToFile(strs: TStrings; const fname: string);
  end;

  TFormIniFiles = class(TFormFileHelper)
  private
    class function GetContainerFileName(const ContainerName: string; const BaseDir: string): string;
    class function GetExternalFileName(const ContainerName: string; const ControlPath: string;
      const PropertyName: string; const BaseDir: string): string;

    class procedure DoSaveContainer(AContainer: TComponent; iniFile: TIniFile;
      const ContainerName: string; SaveFlag: TControlSaveFlag;
      const BaseDir: string; const ParentPath: string);

    class procedure DoLoadContainer(AContainer: TComponent; iniFile: TIniFile;
      const ContainerName: string; SaveFlag: TControlSaveFlag;
      const BaseDir: string; const ParentPath: string);

    class function ShouldProcessControl(ACtrl: TComponent; SaveFlag: TControlSaveFlag): Boolean;

  public
    // 保存/加载整个窗体（包括所有Frame）
    class procedure SaveAllContainers(AForm: TForm; const BaseDir: string='';
      SaveFlag: TControlSaveFlag=csfIgnoreTagOne;
      FormStateOptions: TFormStateOptions=[fsoWindowState, fsoPosition, fsoSize, fsoCaptionR]);

    class procedure LoadAllContainers(AForm: TForm; const BaseDir: string='';
      SaveFlag: TControlSaveFlag=csfIgnoreTagOne;
      FormStateOptions: TFormStateOptions=[fsoWindowState, fsoPosition, fsoSize, fsoCaptionR]);

    // 保存/加载单个容器（Form或Frame）
    class procedure SaveContainer(AContainer: TComponent; const ContainerName: string;
      const BaseDir: string='';
      SaveFlag: TControlSaveFlag=csfIgnoreTagOne;
      FormStateOptions: TFormStateOptions=[fsoWindowState, fsoPosition, fsoSize, fsoCaptionR]);

    class procedure LoadContainer(AContainer: TComponent; const ContainerName: string;
      const BaseDir: string='';
      SaveFlag: TControlSaveFlag=csfIgnoreTagOne;
      FormStateOptions: TFormStateOptions=[fsoWindowState, fsoPosition, fsoSize, fsoCaptionR]);
  end;

implementation

uses Math, CheckLst, ExtCtrls, Spin, Grids, Mask, IOUtils,
  StdCtrls, ComCtrls, Controls, SysUtils;

{ TFormFileHelper }

class function TFormFileHelper.GetAppPath: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

class function TFormFileHelper.ReadFromFile(const fname: string): string;
var
  strs: TStringList;
begin
  strs := TStringList.Create;
  try
    if FileExists(fname) then
    begin
      strs.LoadFromFile(fname, TEncoding.UTF8);
    end;
    Result := strs.Text;
  finally
    strs.Free;
  end;
end;

class procedure TFormFileHelper.StrsFromFile(strs: TStrings; const fname: string);
begin
  if FileExists(fname) then
  begin
    strs.LoadFromFile(fname, TEncoding.UTF8);
  end;
end;

class procedure TFormFileHelper.StrsToFile(strs: TStrings; const fname: string);
begin
  strs.SaveToFile(fname, TEncoding.UTF8);
end;

class procedure TFormFileHelper.SaveToFile(const fname: string; const ctx: string);
var
  strs: TStringList;
begin
  strs := TStringList.Create;
  try
    strs.Text := ctx;
    strs.SaveToFile(fname, TEncoding.UTF8);
  finally
    strs.Free;
  end;
end;

{ TFormIniFiles }

class function TFormIniFiles.GetContainerFileName(const ContainerName: string; const BaseDir: string): string;
begin
  Result := ContainerName + '.ini';
  if BaseDir <> '' then
  begin
    ForceDirectories(BaseDir);
    Result := IncludeTrailingPathDelimiter(BaseDir) + Result;
  end;
end;

class function TFormIniFiles.GetExternalFileName(const ContainerName: string; const ControlPath: string;
  const PropertyName: string; const BaseDir: string): string;
var
  SafePath: string;
begin
  // 生成安全的文件名
  SafePath := ControlPath;
//  SafePath := StringReplace(SafePath, '.', '_', [rfReplaceAll]);
//  SafePath := StringReplace(SafePath, '\', '_', [rfReplaceAll]);
//  SafePath := StringReplace(SafePath, '/', '_', [rfReplaceAll]);
//  SafePath := StringReplace(SafePath, ':', '_', [rfReplaceAll]);
//  SafePath := StringReplace(SafePath, '*', '_', [rfReplaceAll]);
//  SafePath := StringReplace(SafePath, '?', '_', [rfReplaceAll]);
//  SafePath := StringReplace(SafePath, '"', '_', [rfReplaceAll]);
//  SafePath := StringReplace(SafePath, '<', '_', [rfReplaceAll]);
//  SafePath := StringReplace(SafePath, '>', '_', [rfReplaceAll]);
//  SafePath := StringReplace(SafePath, '|', '_', [rfReplaceAll]);

  Result := ContainerName + '_' + SafePath;
  if PropertyName <> '' then
    Result := Result + '_' + PropertyName;
  Result := Result + '.txt';

  if BaseDir <> '' then
  begin
    ForceDirectories(BaseDir);
    Result := IncludeTrailingPathDelimiter(BaseDir) + Result;
  end;
end;

class function TFormIniFiles.ShouldProcessControl(ACtrl: TComponent; SaveFlag: TControlSaveFlag): Boolean;
begin
  Result := True;

  case SaveFlag of
    csfIgnoreTagOne:
      if (ACtrl is TControl) and (TControl(ACtrl).Tag = 1) then
        Result := False;
    csfSaveOnlyTagOne:
      if (ACtrl is TControl) and (TControl(ACtrl).Tag <> 1) then
        Result := False;
    csfSaveTagZero:
      if (ACtrl is TControl) and (TControl(ACtrl).Tag <> 0) then
        Result := False;
  end;
end;

class procedure TFormIniFiles.DoSaveContainer(AContainer: TComponent; iniFile: TIniFile;
  const ContainerName: string; SaveFlag: TControlSaveFlag;
  const BaseDir: string; const ParentPath: string);
var
  I: Integer;
  Ctrl: TComponent;
  ControlPath, FileName: string;
  WinCtrl: TWinControl;
begin
  if not Assigned(AContainer) then Exit;

  for I := 0 to AContainer.ComponentCount - 1 do
  begin
    Ctrl := AContainer.Components[I];

    // 检查是否需要处理此控件
    if not ShouldProcessControl(Ctrl, SaveFlag) then
      Continue;

    // 生成控件路径
    if ParentPath <> '' then
      ControlPath := ParentPath + '.' + Ctrl.Name
    else
      ControlPath := Ctrl.Name;

    if ControlPath = '' then
      Continue;

    // 处理各种控件类型
    if (Ctrl is TEdit) then
    begin
      iniFile.WriteString('Controls', ControlPath + '.Text', TEdit(Ctrl).Text);
    end
    else if (Ctrl is TMemo) then
    begin
      // 保存Lines到单独文件
      FileName := GetExternalFileName(ContainerName, ControlPath, 'Lines', BaseDir);
      StrsToFile(TMemo(Ctrl).Lines, FileName);
      iniFile.WriteString('Controls', ControlPath + '.Lines', '@File');
    end
    else if (Ctrl is TCheckBox) then
    begin
      iniFile.WriteBool('Controls', ControlPath + '.Checked', TCheckBox(Ctrl).Checked);
    end
    else if (Ctrl is TRadioButton) then
    begin
      iniFile.WriteBool('Controls', ControlPath + '.Checked', TRadioButton(Ctrl).Checked);
    end
    else if (Ctrl is TComboBox) then
    begin
      // 保存Items到单独文件
      FileName := GetExternalFileName(ContainerName, ControlPath, 'Items', BaseDir);
      StrsToFile(TComboBox(Ctrl).Items, FileName);
      iniFile.WriteString('Controls', ControlPath + '.Items', '@File');

      // 保存ItemIndex和Text到ini文件
      iniFile.WriteInteger('Controls', ControlPath + '.ItemIndex', TComboBox(Ctrl).ItemIndex);
      iniFile.WriteString('Controls', ControlPath + '.Text', TComboBox(Ctrl).Text);
    end
    else if (Ctrl is TListBox) then
    begin
      // 保存Items到单独文件
      FileName := GetExternalFileName(ContainerName, ControlPath, 'Items', BaseDir);
      StrsToFile(TListBox(Ctrl).Items, FileName);
      iniFile.WriteString('Controls', ControlPath + '.Items', '@File');

      // 保存ItemIndex和TopIndex到ini文件
      iniFile.WriteInteger('Controls', ControlPath + '.ItemIndex', TListBox(Ctrl).ItemIndex);
      iniFile.WriteInteger('Controls', ControlPath + '.TopIndex', TListBox(Ctrl).TopIndex);
    end
    else if (Ctrl is TListView) then
    begin
      // 保存ListView的Items到单独文件
      FileName := GetExternalFileName(ContainerName, ControlPath, 'Items', BaseDir);
      var ListView := TListView(Ctrl);
      var strs := TStringList.Create;
      try
        // 保存列标题
        var ColumnHeaders := '';
        for var J := 0 to ListView.Columns.Count - 1 do
        begin
          if ColumnHeaders <> '' then
            ColumnHeaders := ColumnHeaders + #9;
          ColumnHeaders := ColumnHeaders + ListView.Columns[J].Caption;
        end;
        strs.Add(ColumnHeaders);

        // 保存列宽度
        var ColumnWidths := '';
        for var J := 0 to ListView.Columns.Count - 1 do
        begin
          if ColumnWidths <> '' then
            ColumnWidths := ColumnWidths + ',';
          ColumnWidths := ColumnWidths + IntToStr(ListView.Columns[J].Width);
        end;
        strs.Add(ColumnWidths);

        // 保存列显示顺序
        var ColumnOrder := '';
        for var J := 0 to ListView.Columns.Count - 1 do
        begin
          if ColumnOrder <> '' then
            ColumnOrder := ColumnOrder + ',';
          ColumnOrder := ColumnOrder + IntToStr(ListView.Column[J].ID);
        end;
        strs.Add(ColumnOrder);

        // 保存Items数据
        for var J := 0 to ListView.Items.Count - 1 do
        begin
          var Item := ListView.Items[J];
          var Line := Item.Caption;

          // 保存Checked状态
          Line := Line + '|' + IntToStr(Ord(Item.Checked));

          // 保存SubItems
          for var K := 0 to Item.SubItems.Count - 1 do
          begin
            Line := Line + '|' + Item.SubItems[K];
          end;
          strs.Add(Line);
        end;

        strs.SaveToFile(FileName, TEncoding.UTF8);
      finally
        strs.Free;
      end;
      iniFile.WriteString('Controls', ControlPath + '.Items', '@File');
      iniFile.WriteInteger('Controls', ControlPath + '.ItemIndex', ListView.ItemIndex);
    end
    else if (Ctrl is TRadioGroup) then
    begin
      iniFile.WriteInteger('Controls', ControlPath + '.ItemIndex', TRadioGroup(Ctrl).ItemIndex);
    end
    else if (Ctrl is TCheckListBox) then
    begin
      // 保存选中的项索引
      var CheckedStr := '';
      for var J := 0 to TCheckListBox(Ctrl).Items.Count - 1 do
      begin
        if TCheckListBox(Ctrl).Checked[J] then
        begin
          if CheckedStr <> '' then
            CheckedStr := CheckedStr + ',';
          CheckedStr := CheckedStr + IntToStr(J);
        end;
      end;
      iniFile.WriteString('Controls', ControlPath + '.CheckedIndices', CheckedStr);
    end
    else if (Ctrl is TSpinEdit) then
    begin
      iniFile.WriteInteger('Controls', ControlPath + '.Value', TSpinEdit(Ctrl).Value);
    end
    else if (Ctrl is TDateTimePicker) then
    begin
      iniFile.WriteDateTime('Controls', ControlPath + '.Date', TDateTimePicker(Ctrl).Date);
    end
    else if (Ctrl is TTrackBar) then
    begin
      iniFile.WriteInteger('Controls', ControlPath + '.Position', TTrackBar(Ctrl).Position);
    end
    else if (Ctrl is TPageControl) then
    begin
      iniFile.WriteInteger('Controls', ControlPath + '.ActivePageIndex', TPageControl(Ctrl).ActivePageIndex);
    end
    else if (Ctrl is TMaskEdit) then
    begin
      iniFile.WriteString('Controls', ControlPath + '.Text', TMaskEdit(Ctrl).Text);
    end
    else if (Ctrl is TLabeledEdit) then
    begin
      iniFile.WriteString('Controls', ControlPath + '.Text', TLabeledEdit(Ctrl).Text);
    end
    else if (Ctrl is TStringGrid) then
    begin
      // 保存行数和列数
      iniFile.WriteInteger('Controls', ControlPath + '.RowCount', TStringGrid(Ctrl).RowCount);
      iniFile.WriteInteger('Controls', ControlPath + '.ColCount', TStringGrid(Ctrl).ColCount);
      iniFile.WriteString('Controls', ControlPath + '.Cells', '@File');

      // 保存单元格数据到单独文件
      FileName := GetExternalFileName(ContainerName, ControlPath, 'Cells', BaseDir);
      var strs := TStringList.Create;
      try
        for var Row := 0 to TStringGrid(Ctrl).RowCount - 1 do
        begin
          var RowStr := '';
          for var Col := 0 to TStringGrid(Ctrl).ColCount - 1 do
          begin
            if RowStr <> '' then
              RowStr := RowStr + #9;
            RowStr := RowStr + TStringGrid(Ctrl).Cells[Col, Row];
          end;
          strs.Add(RowStr);
        end;
        strs.SaveToFile(FileName, TEncoding.UTF8);
      finally
        strs.Free;
      end;
    end;

    // 如果是TWinControl，递归处理子控件
    if (Ctrl is TWinControl) then
    begin
      WinCtrl := TWinControl(Ctrl);
      // 只处理非TFrame的容器控件
      if not (Ctrl is TFrame) then
      begin
        DoSaveContainer(WinCtrl, iniFile, ContainerName, SaveFlag, BaseDir, ControlPath);
      end;
    end;
  end;
end;

class procedure TFormIniFiles.DoLoadContainer(AContainer: TComponent; iniFile: TIniFile;
  const ContainerName: string; SaveFlag: TControlSaveFlag;
  const BaseDir: string; const ParentPath: string);
var
  I: Integer;
  Ctrl: TComponent;
  ControlPath, Value, FileName: string;
  WinCtrl: TWinControl;
begin
  if not Assigned(AContainer) then Exit;

  for I := 0 to AContainer.ComponentCount - 1 do
  begin
    Ctrl := AContainer.Components[I];

    // 检查是否需要处理此控件
    if not ShouldProcessControl(Ctrl, SaveFlag) then
      Continue;

    // 生成控件路径
    if ParentPath <> '' then
      ControlPath := ParentPath + '.' + Ctrl.Name
    else
      ControlPath := Ctrl.Name;

    if ControlPath = '' then
      Continue;

    // 处理各种控件类型
    if (Ctrl is TEdit) and iniFile.ValueExists('Controls', ControlPath + '.Text') then
    begin
      TEdit(Ctrl).Text := iniFile.ReadString('Controls', ControlPath + '.Text', TEdit(Ctrl).Text);
    end
    else if (Ctrl is TMemo) and iniFile.ValueExists('Controls', ControlPath + '.Lines') then
    begin
      Value := iniFile.ReadString('Controls', ControlPath + '.Lines', '');
      if Value = '@File' then
      begin
        // 从单独文件加载Lines
        FileName := GetExternalFileName(ContainerName, ControlPath, 'Lines', BaseDir);
        if FileExists(FileName) then
          StrsFromFile(TMemo(Ctrl).Lines, FileName);
      end
      else
      begin
        TMemo(Ctrl).Lines.Text := Value;
      end;
    end
    else if (Ctrl is TCheckBox) and iniFile.ValueExists('Controls', ControlPath + '.Checked') then
    begin
      TCheckBox(Ctrl).Checked := iniFile.ReadBool('Controls', ControlPath + '.Checked', TCheckBox(Ctrl).Checked);
    end
    else if (Ctrl is TRadioButton) and iniFile.ValueExists('Controls', ControlPath + '.Checked') then
    begin
      TRadioButton(Ctrl).Checked := iniFile.ReadBool('Controls', ControlPath + '.Checked', TRadioButton(Ctrl).Checked);
    end
    else if (Ctrl is TComboBox) then
    begin
      if iniFile.ValueExists('Controls', ControlPath + '.Items') then
      begin
        Value := iniFile.ReadString('Controls', ControlPath + '.Items', '');
        if Value = '@File' then
        begin
          // 从单独文件加载Items
          FileName := GetExternalFileName(ContainerName, ControlPath, 'Items', BaseDir);
          if FileExists(FileName) then
            StrsFromFile(TComboBox(Ctrl).Items, FileName);
        end
        else
        begin
          TComboBox(Ctrl).Items.Text := Value;
        end;
      end;

      // 加载ItemIndex和Text
      if iniFile.ValueExists('Controls', ControlPath + '.ItemIndex') then
        TComboBox(Ctrl).ItemIndex := iniFile.ReadInteger('Controls', ControlPath + '.ItemIndex', TComboBox(Ctrl).ItemIndex);
      if iniFile.ValueExists('Controls', ControlPath + '.Text') then
        TComboBox(Ctrl).Text := iniFile.ReadString('Controls', ControlPath + '.Text', TComboBox(Ctrl).Text);
    end
    else if (Ctrl is TListBox) then
    begin
      if iniFile.ValueExists('Controls', ControlPath + '.Items') then
      begin
        Value := iniFile.ReadString('Controls', ControlPath + '.Items', '');
        if Value = '@File' then
        begin
          // 从单独文件加载Items
          FileName := GetExternalFileName(ContainerName, ControlPath, 'Items', BaseDir);
          if FileExists(FileName) then
            StrsFromFile(TListBox(Ctrl).Items, FileName);
        end
        else
        begin
          TListBox(Ctrl).Items.Text := Value;
        end;
      end;

      // 加载ItemIndex和TopIndex
      if iniFile.ValueExists('Controls', ControlPath + '.ItemIndex') then
        TListBox(Ctrl).ItemIndex := iniFile.ReadInteger('Controls', ControlPath + '.ItemIndex', TListBox(Ctrl).ItemIndex);
      if iniFile.ValueExists('Controls', ControlPath + '.TopIndex') then
        TListBox(Ctrl).TopIndex := iniFile.ReadInteger('Controls', ControlPath + '.TopIndex', TListBox(Ctrl).TopIndex);
    end
    else if (Ctrl is TListView) and iniFile.ValueExists('Controls', ControlPath + '.Items') then
    begin
      Value := iniFile.ReadString('Controls', ControlPath + '.Items', '');
      if Value = '@File' then
      begin
        // 从单独文件加载ListView Items
        FileName := GetExternalFileName(ContainerName, ControlPath, 'Items', BaseDir);
        if FileExists(FileName) then
        begin
          var strs := TStringList.Create;
          try
            strs.LoadFromFile(FileName, TEncoding.UTF8);
            if strs.Count >= 3 then
            begin
              // 第一行是列标题
              // 第二行是列宽度
              // 第三行是列顺序
              // 从第四行开始是数据
              var ListView := TListView(Ctrl);

              // 先清空所有项
              ListView.Items.Clear;

              // 加载列信息（可选）
              var ColumnHeaders := TStringList.Create;
              var ColumnWidths := TStringList.Create;
              var ColumnOrder := TStringList.Create;
              try
                ColumnHeaders.Delimiter := #9;
                ColumnHeaders.StrictDelimiter := True;
                ColumnHeaders.DelimitedText := strs[0];

                ColumnWidths.Delimiter := ',';
                ColumnWidths.StrictDelimiter := True;
                ColumnWidths.DelimitedText := strs[1];

                ColumnOrder.Delimiter := ',';
                ColumnOrder.StrictDelimiter := True;
                ColumnOrder.DelimitedText := strs[2];

                // 如果有列信息，但当前没有列，可以动态创建
                // 这里假设列已经设计时创建好了
              finally
                ColumnHeaders.Free;
                ColumnWidths.Free;
                ColumnOrder.Free;
              end;

              // 加载Items
              ListView.Items.BeginUpdate;
              try
                for var J := 3 to strs.Count - 1 do
                begin
                  var Parts := TStringList.Create;
                  try
                    Parts.Delimiter := '|';
                    Parts.StrictDelimiter := True;
                    Parts.DelimitedText := strs[J];

                    if Parts.Count >= 1 then
                    begin
                      var ListItem := ListView.Items.Add;
                      ListItem.Caption := Parts[0];

                      if Parts.Count >= 2 then
                      begin
                        ListItem.Checked := StrToIntDef(Parts[1], 0) <> 0;
                      end;

                      // 加载SubItems
                      for var K := 2 to Parts.Count - 1 do
                      begin
                        ListItem.SubItems.Add(Parts[K]);
                      end;
                    end;
                  finally
                    Parts.Free;
                  end;
                end;
              finally
                ListView.Items.EndUpdate;
              end;
            end;
          finally
            strs.Free;
          end;
        end;

        // 加载ItemIndex
        if iniFile.ValueExists('Controls', ControlPath + '.ItemIndex') then
          TListView(Ctrl).ItemIndex := iniFile.ReadInteger('Controls', ControlPath + '.ItemIndex', TListView(Ctrl).ItemIndex);
      end;
    end
    else if (Ctrl is TRadioGroup) and iniFile.ValueExists('Controls', ControlPath + '.ItemIndex') then
    begin
      TRadioGroup(Ctrl).ItemIndex := iniFile.ReadInteger('Controls', ControlPath + '.ItemIndex', TRadioGroup(Ctrl).ItemIndex);
    end
    else if (Ctrl is TCheckListBox) and iniFile.ValueExists('Controls', ControlPath + '.CheckedIndices') then
    begin
      // 加载选中的项
      Value := iniFile.ReadString('Controls', ControlPath + '.CheckedIndices', '');
      var CheckedItems := TStringList.Create;
      try
        CheckedItems.CommaText := Value;
        for var J := 0 to CheckedItems.Count - 1 do
        begin
          var ItemIndex := StrToIntDef(CheckedItems[J], -1);
          if ItemIndex >= 0 then
            TCheckListBox(Ctrl).Checked[ItemIndex] := True;
        end;
      finally
        CheckedItems.Free;
      end;
    end
    else if (Ctrl is TSpinEdit) and iniFile.ValueExists('Controls', ControlPath + '.Value') then
    begin
      TSpinEdit(Ctrl).Value := iniFile.ReadInteger('Controls', ControlPath + '.Value', TSpinEdit(Ctrl).Value);
    end
    else if (Ctrl is TDateTimePicker) and iniFile.ValueExists('Controls', ControlPath + '.Date') then
    begin
      TDateTimePicker(Ctrl).Date := iniFile.ReadDateTime('Controls', ControlPath + '.Date', TDateTimePicker(Ctrl).Date);
    end
    else if (Ctrl is TTrackBar) and iniFile.ValueExists('Controls', ControlPath + '.Position') then
    begin
      TTrackBar(Ctrl).Position := iniFile.ReadInteger('Controls', ControlPath + '.Position', TTrackBar(Ctrl).Position);
    end
    else if (Ctrl is TPageControl) and iniFile.ValueExists('Controls', ControlPath + '.ActivePageIndex') then
    begin
      TPageControl(Ctrl).ActivePageIndex := iniFile.ReadInteger('Controls', ControlPath + '.ActivePageIndex', TPageControl(Ctrl).ActivePageIndex);
    end
    else if (Ctrl is TMaskEdit) and iniFile.ValueExists('Controls', ControlPath + '.Text') then
    begin
      TMaskEdit(Ctrl).Text := iniFile.ReadString('Controls', ControlPath + '.Text', TMaskEdit(Ctrl).Text);
    end
    else if (Ctrl is TLabeledEdit) and iniFile.ValueExists('Controls', ControlPath + '.Text') then
    begin
      TLabeledEdit(Ctrl).Text := iniFile.ReadString('Controls', ControlPath + '.Text', TLabeledEdit(Ctrl).Text);
    end
    else if (Ctrl is TStringGrid) and iniFile.ValueExists('Controls', ControlPath + '.Cells') then
    begin
      Value := iniFile.ReadString('Controls', ControlPath + '.Cells', '');
      if Value = '@File' then
      begin
        // 从单独文件加载单元格数据
        FileName := GetExternalFileName(ContainerName, ControlPath, 'Cells', BaseDir);
        if FileExists(FileName) then
        begin
          var strs := TStringList.Create;
          try
            strs.LoadFromFile(FileName, TEncoding.UTF8);
            var RowCount := iniFile.ReadInteger('Controls', ControlPath + '.RowCount', TStringGrid(Ctrl).RowCount);
            var ColCount := iniFile.ReadInteger('Controls', ControlPath + '.ColCount', TStringGrid(Ctrl).ColCount);

            TStringGrid(Ctrl).RowCount := RowCount;
            TStringGrid(Ctrl).ColCount := ColCount;

            for var Row := 0 to Min(strs.Count - 1, RowCount - 1) do
            begin
              var RowValues := TStringList.Create;
              try
                RowValues.Delimiter := #9;
                RowValues.StrictDelimiter := True;
                RowValues.DelimitedText := strs[Row];

                for var Col := 0 to Min(RowValues.Count - 1, ColCount - 1) do
                begin
                  TStringGrid(Ctrl).Cells[Col, Row] := RowValues[Col];
                end;
              finally
                RowValues.Free;
              end;
            end;
          finally
            strs.Free;
          end;
        end;
      end;
    end;

    // 如果是TWinControl，递归处理子控件
    if (Ctrl is TWinControl) then
    begin
      WinCtrl := TWinControl(Ctrl);
      // 只处理非TFrame的容器控件
      if not (Ctrl is TFrame) then
      begin
        DoLoadContainer(WinCtrl, iniFile, ContainerName, SaveFlag, BaseDir, ControlPath);
      end;
    end;
  end;
end;

class procedure TFormIniFiles.SaveAllContainers(AForm: TForm; const BaseDir: string;
  SaveFlag: TControlSaveFlag; FormStateOptions: TFormStateOptions);
var
  I, J: Integer;
  Frame: TFrame;
  FrameName, Dir: string;
begin
  if not Assigned(AForm) then Exit;

  // 设置保存目录
  Dir := BaseDir;
  if Dir = '' then
    Dir := IncludeTrailingPathDelimiter(GetAppPath) + 'data\settings\';

  // 创建目录
  ForceDirectories(Dir);

  // 保存主窗体
  SaveContainer(AForm, AForm.Name, Dir, SaveFlag, FormStateOptions);

  // 递归保存所有Frame
  for I := 0 to AForm.ComponentCount - 1 do
  begin
    if AForm.Components[I] is TFrame then
    begin
      Frame := TFrame(AForm.Components[I]);
      if Frame.Name <> '' then
        FrameName := Frame.Name
      else
        FrameName := 'Frame' + IntToStr(I);

      // 保存Frame
      SaveContainer(Frame, FrameName, Dir, SaveFlag, []);

      // 递归保存Frame内的Frame
      for J := 0 to Frame.ComponentCount - 1 do
      begin
        if Frame.Components[J] is TFrame then
        begin
          // 递归处理嵌套Frame
          SaveAllContainers(TForm(Frame.Components[J]), Dir, SaveFlag, []);
        end;
      end;
    end;
  end;
end;

class procedure TFormIniFiles.LoadAllContainers(AForm: TForm; const BaseDir: string;
  SaveFlag: TControlSaveFlag; FormStateOptions: TFormStateOptions);
var
  I, J: Integer;
  Frame: TFrame;
  FrameName, Dir, FileName: string;
begin
  if not Assigned(AForm) then Exit;

  // 设置加载目录
  Dir := BaseDir;
  if Dir = '' then
    Dir := IncludeTrailingPathDelimiter(GetAppPath) + 'data\settings\';

  // 加载主窗体
  LoadContainer(AForm, AForm.Name, Dir, SaveFlag, FormStateOptions);

  // 递归加载所有Frame
  for I := 0 to AForm.ComponentCount - 1 do
  begin
    if AForm.Components[I] is TFrame then
    begin
      Frame := TFrame(AForm.Components[I]);
      if Frame.Name <> '' then
        FrameName := Frame.Name
      else
        FrameName := 'Frame' + IntToStr(I);

      FileName := GetContainerFileName(FrameName, Dir);
      if FileExists(FileName) then
      begin
        // 加载Frame
        LoadContainer(Frame, FrameName, Dir, SaveFlag, []);
      end;

      // 递归加载Frame内的Frame
      for J := 0 to Frame.ComponentCount - 1 do
      begin
        if Frame.Components[J] is TFrame then
        begin
          LoadAllContainers(TForm(Frame.Components[J]), Dir, SaveFlag, []);
        end;
      end;
    end;
  end;
end;

class procedure TFormIniFiles.SaveContainer(AContainer: TComponent; const ContainerName: string;
  const BaseDir: string; SaveFlag: TControlSaveFlag; FormStateOptions: TFormStateOptions);
var
  Dir, FileName: string;
  iniFile: TIniFile;
begin
  if not Assigned(AContainer) or (ContainerName = '') then Exit;

  // 设置保存目录
  Dir := BaseDir;
  if Dir = '' then
    Dir := IncludeTrailingPathDelimiter(GetAppPath) + 'data\settings\';

  // 创建目录
  ForceDirectories(Dir);

  // 生成文件名
  FileName := GetContainerFileName(ContainerName, Dir);
  iniFile := TIniFile.Create(FileName);
  try
    // 如果是TForm，保存窗体属性
    if AContainer is TForm then
    begin
      if fsoPosition in FormStateOptions then
      begin
        iniFile.WriteInteger('Form', 'Top', TForm(AContainer).Top);
        iniFile.WriteInteger('Form', 'Left', TForm(AContainer).Left);
      end;

      if fsoSize in FormStateOptions then
      begin
        iniFile.WriteInteger('Form', 'Height', TForm(AContainer).Height);
        iniFile.WriteInteger('Form', 'Width', TForm(AContainer).Width);
      end;

      if fsoWindowState in FormStateOptions then
        iniFile.WriteInteger('Form', 'WindowState', Ord(TForm(AContainer).WindowState));

      if fsoCaptionW in FormStateOptions then
        iniFile.WriteString('Form', 'Caption', TForm(AContainer).Caption);
    end;

    // 处理容器内的控件
    DoSaveContainer(AContainer, iniFile, ContainerName, SaveFlag, Dir, '');

  finally
    iniFile.Free;
  end;
end;

class procedure TFormIniFiles.LoadContainer(AContainer: TComponent; const ContainerName: string;
  const BaseDir: string; SaveFlag: TControlSaveFlag; FormStateOptions: TFormStateOptions);
var
  Dir, FileName: string;
  iniFile: TIniFile;
begin
  if not Assigned(AContainer) or (ContainerName = '') then Exit;

  // 设置加载目录
  Dir := BaseDir;
  if Dir = '' then
    Dir := IncludeTrailingPathDelimiter(GetAppPath) + 'data\settings\';

  // 检查文件是否存在
  FileName := GetContainerFileName(ContainerName, Dir);
  if not FileExists(FileName) then Exit;

  iniFile := TIniFile.Create(FileName);
  try
    // 如果是TForm，加载窗体属性
    if AContainer is TForm then
    begin
      if fsoPosition in FormStateOptions then
      begin
        TForm(AContainer).Top := iniFile.ReadInteger('Form', 'Top', TForm(AContainer).Top);
        TForm(AContainer).Left := iniFile.ReadInteger('Form', 'Left', TForm(AContainer).Left);
      end;

      if fsoSize in FormStateOptions then
      begin
        TForm(AContainer).Height := iniFile.ReadInteger('Form', 'Height', TForm(AContainer).Height);
        TForm(AContainer).Width := iniFile.ReadInteger('Form', 'Width', TForm(AContainer).Width);
      end;

      if fsoWindowState in FormStateOptions then
        TForm(AContainer).WindowState := TWindowState(iniFile.ReadInteger('Form', 'WindowState', 0));

      if fsoCaptionR in FormStateOptions then
      begin
        var CaptionStr: string := iniFile.ReadString('Form', 'Caption', TForm(AContainer).Caption);
        if not CaptionStr.IsEmpty then
          TForm(AContainer).Caption := CaptionStr;
      end;
    end;

    // 处理容器内的控件
    DoLoadContainer(AContainer, iniFile, ContainerName, SaveFlag, Dir, '');

  finally
    iniFile.Free;
  end;
end;

end.
