
" ============================================================
" -1 : only when all git info supplied
" 0 : disable
" 1 : enable, may ask user to input git info
if !exists('g:ZFVimIM_cloudSync_enable')
    let g:ZFVimIM_cloudSync_enable=-1
endif
if !exists('g:ZFVimIM_cloudSync_confirm')
    let g:ZFVimIM_cloudSync_confirm=0
endif


" ============================================================
function! ZFVimIM_initSync(cloudOption)
    call s:initSync(a:cloudOption)
endfunction


function! ZFVimIM_downloadSync(cloudOption)
    call s:uploadSync(a:cloudOption, 'download')
endfunction
function! ZFVimIM_downloadAllSync()
    call ZFVimIM_downloadAllAsyncCancel()
    call ZFVimIM_uploadAllAsyncCancel()
    for cloudOption in g:ZFVimIM_cloudOption
        call ZFVimIM_downloadSync(cloudOption)
    endfor
endfunction


function! ZFVimIM_uploadSync(cloudOption)
    call s:uploadSync(a:cloudOption, 'upload')
endfunction
function! ZFVimIM_uploadAllSync()
    call ZFVimIM_downloadAllAsyncCancel()
    call ZFVimIM_uploadAllAsyncCancel()
    for cloudOption in g:ZFVimIM_cloudOption
        call ZFVimIM_uploadSync(cloudOption)
    endfor
endfunction


" ============================================================
augroup ZFVimIM_cloud_sync_augroup
    autocmd!
    autocmd VimLeavePre *
                \  if g:ZFVimIM_cloudSync_enable == 1 || (g:ZFVimIM_cloudSync_enable == -1 && s:US_containUploadable())
                \|     call ZFVimIM_uploadAllSync()
                \| endif
augroup END

" ============================================================
function! s:US_containUploadable()
    for cloudOption in g:ZFVimIM_cloudOption
        if ZFVimIM_cloud_gitInfoSupplied(cloudOption) || (get(cloudOption, 'mode', '') == 'local')
            return 1
        endif
    endfor
    return 0
endfunction

function! s:US_gitInfoPrepare(cloudOption, downloadOnly)
    if !isdirectory(get(a:cloudOption, 'repoPath', ''))
        redraw!
        call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . 'invalid repoPath: ' . get(a:cloudOption, 'repoPath', ''))
        return 0
    endif
    if filewritable(ZFVimIM_cloud_file(a:cloudOption, 'dbFile')) != 1
        redraw!
        call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . 'invalid dbFile: ' . ZFVimIM_cloud_file(a:cloudOption, 'dbFile'))
        return 0
    endif

    let gitInfo = {
                \   'gitUserEmail' : get(a:cloudOption, 'gitUserEmail', ''),
                \   'gitUserName' : get(a:cloudOption, 'gitUserName', ''),
                \   'gitUserToken' : get(a:cloudOption, 'gitUserToken', ''),
                \ }

    let reInput = 0
    let success = 0
    let hasInput = 0
    while 1
        if a:downloadOnly
            let success = 1
        endif

        if reInput || empty(gitInfo['gitUserEmail'])
            let gitInfo['gitUserEmail'] = input('[ZFVimIM_sync] input user email: ', gitInfo['gitUserEmail'])
            let hasInput = 1
            if empty(gitInfo['gitUserEmail'])
                break
            endif
        endif
        if reInput || empty(gitInfo['gitUserName'])
            let gitInfo['gitUserName'] = input('[ZFVimIM_sync] input user name: ', gitInfo['gitUserName'])
            let hasInput = 1
            if empty(gitInfo['gitUserName'])
                break
            endif
        endif
        if reInput || empty(gitInfo['gitUserToken'])
            let gitInfo['gitUserToken'] = inputsecret('[ZFVimIM_sync] input user pwd: ', gitInfo['gitUserToken'])
            let hasInput = 1
            if empty(gitInfo['gitUserToken'])
                break
            endif
        endif

        if !g:ZFVimIM_cloudSync_confirm && !hasInput
            let success = 1
            break
        endif

        let pwdFix = gitInfo['gitUserToken']
        if len(pwdFix) > 3
            let pwdFix = strpart(pwdFix, 0, 3) . repeat('*', len(pwdFix) - 3)
        endif

        redraw!
        echo '[ZFVimIM_sync] upload with these user info?'
        echo '   repo: ' . a:cloudOption['repoPath']
        echo '   file: ' . a:cloudOption['dbFile']
        echo '  email: ' . gitInfo['gitUserEmail']
        echo '   name: ' . gitInfo['gitUserName']
        echo '    pwd: ' . pwdFix
        echo ''
        echo '(y)es / (n)o / (e)dit: '
        let choose = getchar()
        if choose == char2nr('e')
            let reInput = 1
            redraw!
            continue
        elseif choose == char2nr('y')
            let success = 1
            break
        else
            break
        endif
    endwhile

    redraw!
    if success
        let a:cloudOption['gitUserEmail'] = gitInfo['gitUserEmail']
        let a:cloudOption['gitUserName'] = gitInfo['gitUserName']
        let a:cloudOption['gitUserToken'] = gitInfo['gitUserToken']
    else
        if !reInput && !hasInput
            redraw!
            call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . 'missing git info')
        else
            redraw!
            call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . 'canceled')
        endif
        return 0
    endif
    return 1
endfunction

function! s:cloudSyncLog(msg)
    echo a:msg
    call ZFVimIM_cloudLogAdd(a:msg)
endfunction

function! s:initSync(cloudOption)
    let db = ZFVimIM_dbForId(a:cloudOption['dbId'])
    call ZFVimIM_dbLoad(db, ZFVimIM_cloud_file(a:cloudOption, 'dbFile'), ZFVimIM_cloud_file(a:cloudOption, 'dbCountFile'))
endfunction

" mode:
" * download
" * upload
function! s:uploadSync(cloudOption, mode)
    call ZFVimIM_cloudLogClear()

    let localMode = (get(a:cloudOption, 'mode', '') == 'local')
    let downloadOnly = (a:mode == 'download')

    if !localMode && !executable('git')
        redraw!
        call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . 'canceled: git not available')
        return
    endif

    let db = ZFVimIM_dbForId(a:cloudOption['dbId'])
    if !downloadOnly && empty(db['dbEdit'])
        redraw!
        call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . 'canceled: nothing to push')
        return
    endif

    if !localMode
        if !s:US_gitInfoPrepare(a:cloudOption, downloadOnly)
            return
        endif
    endif

    if !localMode
        redraw!
        call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . 'updating...')
        let result = system(ZFVimIM_cloud_dbDownloadCmd(a:cloudOption))
        if v:shell_error
            call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . ZFVimIM_cloud_dbDownloadCmd(a:cloudOption))
            let result = ZFVimIM_cloud_fixOutputEncoding(result)
            call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . result)
            return
        endif
    endif

    redraw!
    call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . 'merging...')
    let dbFile = ZFVimIM_cloud_file(a:cloudOption, 'dbFile')
    let dbCountFile = ZFVimIM_cloud_file(a:cloudOption, 'dbCountFile')
    let db = ZFVimIM_dbForId(a:cloudOption['dbId'])
    let dbNew = {}
    call ZFVimIM_dbLoad(dbNew, dbFile, dbCountFile)

    if downloadOnly
        let db['dbMap'] = dbNew['dbMap']
    else
        if !empty(db['dbEdit'])
            let logHead = ZFVimIM_cloud_logInfo(a:cloudOption)
            call s:cloudSyncLog(logHead . 'changes:')
            for dbEdit in db['dbEdit']
                call s:cloudSyncLog(logHead . '  ' . printf('%6s', dbEdit['action']) . "\t" . dbEdit['key'] . ' ' . dbEdit['word'])
            endfor
        endif

        call ZFVimIM_dbEditApply(dbNew, db['dbEdit'])
        call ZFVimIM_dbSave(dbNew, dbFile, dbCountFile)

        if !localMode
            redraw!
            call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . 'pushing...')
            let result = system(ZFVimIM_cloud_dbUploadCmd(a:cloudOption))
            " strip password
            let result = substitute(result, ':[^:]*@', '@', 'g')
            if v:shell_error
                call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . ZFVimIM_cloud_dbUploadCmd(a:cloudOption))
                let result = ZFVimIM_cloud_fixOutputEncoding(result)
                call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . result)
                return
            endif
        endif

        let db['dbMap'] = dbNew['dbMap']
        let db['dbEdit'] = []
    endif

    redraw!
    call s:cloudSyncLog(ZFVimIM_cloud_logInfo(a:cloudOption) . 'update success')
endfunction

