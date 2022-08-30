__package__ = 'archivebox.extractors'

from pathlib import Path
from time import sleep
from typing import Optional

from waybackpy import WaybackMachineSaveAPI, __version__
from waybackpy.exceptions import MaximumSaveRetriesExceeded, TooManyRequestsError, WaybackError

from ..index.schema import Link, ArchiveResult
from ..util import (
    enforce_types,
    is_static_file,
    can_perform_action,
    increment_action_counter,
    UserAgentFormatter,
)
from ..config import (
    TIMEOUT,
    SAVE_ARCHIVE_DOT_ORG,
    CURL_USER_AGENT
)
from ..logging_util import TimedProgress


@enforce_types
def should_save_archive_dot_org(link: Link, out_dir: Optional[Path]=None, overwrite: Optional[bool]=False) -> bool:
    if is_static_file(link.url) or not can_perform_action():
        return False

    return SAVE_ARCHIVE_DOT_ORG

@enforce_types
def save_archive_dot_org(link: Link, out_dir: Optional[Path]=None, timeout: int=TIMEOUT) -> ArchiveResult:
    """submit site to archive.org for archiving via their service, save returned archive url"""

    increment_action_counter()  # Register the call into the main action counter
    out_dir = out_dir or Path(link.link_dir)
    output: str = ''
    timer = TimedProgress(timeout, prefix='      ')
    status = ''
    retries = 6  # Give it a whole minute to retry
    while not status:
        try:
            if can_perform_action():
                save_api = WaybackMachineSaveAPI(link.url, UserAgentFormatter(CURL_USER_AGENT).get_agent())
                output = save_api.save()
                status = 'succeeded'
            else:
                if not retries:
                    raise MaximumSaveRetriesExceeded('Maximum number of retries exceeded.')
                sleep(10)
                retries -= 1
        except TooManyRequestsError:  # The Internet Archive allows up to 15 requests per minute, otherwise blocks you for 5 minutes.
            sleep(60 * 5)
        except (MaximumSaveRetriesExceeded, WaybackError) as e:
            status = 'failed'
            output = str(e)
    timer.end()

    return ArchiveResult(
        cmd=['waybackpy'],
        pwd=str(out_dir),
        cmd_version=__version__,
        output=output,
        status=status,
        **timer.stats,
    )
